import Foundation

public enum SafetyPolicy {
    private static let forbiddenRoots = ["/System", "/usr", "/bin", "/sbin", "/private/var/db"]
    private static let protectedMarkers = [
        "/Library/Metadata/", "/Library/Spotlight/", "/Library/Knowledge/",
        "/Library/Suggestions/", "/Library/WebKit/", "/Library/HTTPStorages/"
    ]

    public static func canScan(_ path: String) -> Bool {
        !forbiddenRoots.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    public static func canDelete(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard path.hasPrefix(home + "/") || path.hasPrefix("/Applications/") else { return false }
        guard canScan(path) else { return false }
        return !protectedMarkers.contains { path.contains($0) }
    }

    public static func shouldSkipDuringUserScan(_ path: String) -> Bool {
        protectedMarkers.contains { path.contains($0) }
    }
}
