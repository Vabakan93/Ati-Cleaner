import Foundation

public struct SystemDataItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let isProtected: Bool
    public let isUnnecessary: Bool
    public var isSelected: Bool
    public init(name: String, path: String, size: Int64, isProtected: Bool = false, isUnnecessary: Bool = false, isSelected: Bool = false) {
        self.id = path; self.name = name; self.path = path; self.size = size; self.isProtected = isProtected; self.isUnnecessary = isUnnecessary; self.isSelected = isSelected
    }
}

public struct SystemDataScanner: Sendable {
    public init() {}

    public func scan() -> [SystemDataItem] {
        let root = URL(fileURLWithPath: SafetyPolicy.systemAppSupportRoot)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let inUseNames = Self.inUseFolderNames()
        var items: [SystemDataItem] = []
        for entry in entries {
            let v = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = v?.isDirectory ?? false
            let size = isDir ? FileUtilities.recursiveSize(of: entry) : Int64((try? entry.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            let protected = SafetyPolicy.isSystemProtected(entry.path)
            let name = entry.lastPathComponent
            let unnecessary = !protected && !Self.isInUse(name: name, keywords: inUseNames)
            items.append(.init(
                name: name,
                path: entry.path,
                size: size,
                isProtected: protected,
                isUnnecessary: unnecessary
            ))
        }
        return items.sorted { $0.size > $1.size }
    }

    private static func isInUse(name: String, keywords: [String]) -> Bool {
        let tokens = name.split(separator: " ").map(String.init)
        return keywords.contains { keyword in
            if keyword.localizedCaseInsensitiveContains(name) { return true }
            return tokens.contains { keyword.localizedCaseInsensitiveContains($0) }
        }
    }

    private static func inUseFolderNames() -> [String] {
        let apps = AppScanner.installedApps()
        var keywords: Set<String> = []
        for app in apps {
            let name = app.name.lowercased().replacingOccurrences(of: " ", with: "")
            if name.count >= 3 { keywords.insert(name) }
            if let bid = app.bundleIdentifier?.lowercased() {
                let compact = bid.replacingOccurrences(of: ".", with: "")
                if compact.count >= 3 { keywords.insert(compact) }
            }
        }
        return Array(keywords)
    }
}

public enum SystemDataCleaner {
    public static func performDelete(_ paths: [String]) -> Bool {
        var ok = true
        for p in paths where SafetyPolicy.canSystemDelete(p) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/rm")
            process.arguments = ["-rf", "--", p]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 { ok = false }
            } catch {
                ok = false
            }
        }
        return ok
    }
}