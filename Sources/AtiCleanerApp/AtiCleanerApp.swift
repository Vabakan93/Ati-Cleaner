import SwiftUI
import AtiCleanerCore

@main
struct AtiCleanerApp: App {
    init() {
        UserDefaults.standard.register(defaults: [SafetyPolicy.excludedVolumesKey: "gamess,Yedek"])
        if CommandLine.arguments.contains("--purge") {
            let token = (try? String(contentsOfFile: PrivilegedHelper.triggerPath, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ok: Bool
            if let request = try? String(contentsOfFile: PrivilegedHelper.deleteRequestPath, encoding: .utf8) {
                let paths = request.split(separator: "\n").map(String.init)
                ok = SystemDataCleaner.performDelete(paths)
                try? FileManager.default.removeItem(atPath: PrivilegedHelper.deleteRequestPath)
            } else {
                ok = MemoryService.runPurge()
            }
            let marker = PrivilegedHelper.resultPath + "-" + token
            try? (ok ? "ok" : "fail").write(toFile: marker, atomically: true, encoding: .utf8)
            exit(ok ? 0 : 1)
        }
    }
    var body: some Scene {
        WindowGroup("Ati Cleaner") {
            RootView()
                .frame(minWidth: 1040, minHeight: 700)
                .tint(Theme.accent)
        }
        .windowStyle(.titleBar)
    }
}
