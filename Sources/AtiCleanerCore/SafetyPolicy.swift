import Foundation

public enum SafetyPolicy {
    private static let forbiddenRoots = ["/System", "/usr", "/bin", "/sbin", "/private/var/db"]
    private static let protectedMarkers = [
        "/Library/Metadata/", "/Library/Spotlight/", "/Library/Knowledge/",
        "/Library/Suggestions/", "/Library/WebKit/", "/Library/HTTPStorages/"
    ]
    private static let deleteProtectedMarkers = [
        "/Library/Mobile Documents/", "/Library/Mail/", "/Library/Messages/"
    ]
    private static let tccProtectedCaches = [
        "CloudKit", "com.apple.Safari", "FamilyCircle", "com.apple.Maps",
        "com.apple.helpd", "com.apple.photos", "com.apple.Accessibility",
        "com.apple.WebKit", "com.apple.HIToolbox"
    ]

    public static let excludedVolumesKey = "excludedVolumes"

    public static var excludedVolumeNames: [String] {
        let raw = UserDefaults.standard.string(forKey: excludedVolumesKey) ?? ""
        return raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public static func setExcludedVolumeNames(_ names: [String]) {
        UserDefaults.standard.set(names.joined(separator: ","), forKey: excludedVolumesKey)
    }

    public static func isExcludedVolume(_ path: String) -> Bool {
        excludedVolumeNames.contains { name in
            let base = "/Volumes/\(name)"
            return path == base || path.hasPrefix(base + "/")
        }
    }

    public static func canScan(_ path: String) -> Bool {
        if isExcludedVolume(path) { return false }
        return !forbiddenRoots.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    public static func canDelete(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard path.hasPrefix(home + "/") || path.hasPrefix("/Applications/") else { return false }
        guard canScan(path) else { return false }
        guard !deleteProtectedMarkers.contains(where: { path.contains($0) }) else { return false }
        return !protectedMarkers.contains { path.contains($0) }
    }

    public static func shouldSkipDuringUserScan(_ path: String) -> Bool {
        protectedMarkers.contains { path.contains($0) }
    }

    public static func isTCCProtected(_ path: String) -> Bool {
        let caches = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches").path
        return tccProtectedCaches.contains { name in
            let base = caches + "/" + name
            return path == base || path.hasPrefix(base + "/")
        }
    }

    public static func isHomeLibrary(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path == home + "/Library" || path.hasPrefix(home + "/Library/")
    }

    public static func shouldSkipDescendants(of path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let protected: [String] = [
            "/Library/Mail", "/Library/Messages", "/Library/Notes",
            "/Library/Reminders", "/Library/Calendars", "/Library/Accounts",
            "/Library/Safari", "/Library/CallServices", "/Library/IdentityServices",
            "/Library/VoiceMemos", "/Library/Application Support/AddressBook",
            "/Library/Containers/com.apple.MobileSMS",
            "/Library/Containers/com.apple.mobileslideshow",
            "/Library/Group Containers/group.com.apple.notes",
            "/Music/Media", "/Music/Music Library", "/Music/iTunes"
        ]
        for p in protected {
            if path == home + p || path.hasPrefix(home + p + "/") { return true }
        }
        if path.contains(".photoslibrary") || path.contains(".musiclibrary") { return true }
        return false
    }
}
