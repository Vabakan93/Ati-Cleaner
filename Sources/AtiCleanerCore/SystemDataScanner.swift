import Foundation

public struct SystemDataItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let isProtected: Bool
    public var isSelected: Bool
    public init(name: String, path: String, size: Int64, isProtected: Bool = false, isSelected: Bool = false) {
        self.id = path; self.name = name; self.path = path; self.size = size; self.isProtected = isProtected; self.isSelected = isSelected
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
        var items: [SystemDataItem] = []
        for entry in entries {
            let v = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = v?.isDirectory ?? false
            let size = isDir ? FileUtilities.recursiveSize(of: entry) : Int64((try? entry.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            items.append(.init(
                name: entry.lastPathComponent,
                path: entry.path,
                size: size,
                isProtected: SafetyPolicy.isSystemProtected(entry.path)
            ))
        }
        return items.sorted { $0.size > $1.size }
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