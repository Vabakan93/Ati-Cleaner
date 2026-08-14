import Foundation

public enum PrivilegedHelper {
    public static let label = "com.aticleaner.purge"
    public static let installPath = "/Library/PrivilegedHelperTools/aticleaner-purge"
    public static let plistPath = "/Library/LaunchDaemons/\(label).plist"
    public static let triggerPath = "/var/tmp/aticleaner-purge-trigger"
    public static let resultPath = "/var/tmp/aticleaner-purge-result"

    public static func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: installPath) &&
        FileManager.default.fileExists(atPath: plistPath)
    }

    @discardableResult
    public static func install(sourceBinary: String) -> Bool {
        let plist = daemonPlist()
        let script = """
        mkdir -p /Library/PrivilegedHelperTools
        rm -f '\(installPath)'
        cp '\(sourceBinary)' '\(installPath)'
        chown root:wheel '\(installPath)'
        chmod 755 '\(installPath)'
        rm -f '\(plistPath)'
        cat > '\(plistPath)' <<'PLISTEOF'
        \(plist)
        PLISTEOF
        chown root:wheel '\(plistPath)'
        chmod 644 '\(plistPath)'
        launchctl unload '\(plistPath)' 2>/dev/null || true
        launchctl load -w '\(plistPath)' 2>/dev/null || launchctl bootstrap system '\(plistPath)'
        launchctl list | grep -q '\(label)'
        """
        return runAsAdmin(script)
    }

    @discardableResult
    public static func uninstall() -> Bool {
        let script = """
        launchctl unload '\(plistPath)' 2>/dev/null || true
        rm -f '\(plistPath)'
        rm -f '\(installPath)'
        rm -f '\(triggerPath)'
        rm -f '\(resultPath)'*
        """
        return runAsAdmin(script)
    }

    public static func trigger() -> String? {
        let token = UUID().uuidString
        do {
            try token.write(toFile: triggerPath, atomically: false, encoding: .utf8)
            return token
        } catch {
            return nil
        }
    }

    public static func waitForCompletion(token: String, timeout: TimeInterval = 8) -> Bool {
        let resultFile = resultPath + "-" + token
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let contents = try? String(contentsOfFile: resultFile, encoding: .utf8) {
                let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "ok" { return true }
                if trimmed == "fail" { return false }
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }

    private static func daemonPlist() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(installPath)</string>
                <string>--purge</string>
            </array>
            <key>WatchPaths</key>
            <array><string>\(triggerPath)</string></array>
            <key>StandardOutPath</key><string>/dev/null</string>
            <key>StandardErrorPath</key><string>/dev/null</string>
        </dict>
        </plist>
        """
    }

    private static func runAsAdmin(_ command: String) -> Bool {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}