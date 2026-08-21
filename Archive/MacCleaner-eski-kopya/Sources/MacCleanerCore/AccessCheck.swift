import Foundation

public enum AccessCheck {

    public static func hasFullDiskAccess() -> Bool {
        let probePaths = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mail").path
        ]

        for path in probePaths {
            if let data = FileManager.default.contents(atPath: path), !data.isEmpty {
                return true
            }
        }
        return false
    }

    public static func isTrashReadable() -> Bool {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: trash.path, isDirectory: &isDir), isDir.boolValue else { return false }
        return (try? FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil, options: [])) != nil
    }
}