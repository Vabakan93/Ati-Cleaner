import Foundation

public struct DeleteResult: Sendable {
    public let deleted: [String]
    public let failed: [(path: String, reason: String)]
    public var succeeded: Int { deleted.count }
    public init(deleted: [String], failed: [(path: String, reason: String)]) {
        self.deleted = deleted; self.failed = failed
    }
}

public enum FileUtilities {
    public static func recursiveSize(of url: URL, isCancelled: () -> Bool = { false }) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        var total: Int64 = 0
        guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey], options: [.skipsPackageDescendants]) else { return 0 }
        for case let child as URL in e {
            if isCancelled() { break }
            let v = try? child.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
            if v?.isSymbolicLink == true { continue }
            if v?.isRegularFile == true { total += Int64(v?.fileSize ?? 0) }
        }
        return total
    }

    public static func delete(paths: [String], permanent: Bool) -> DeleteResult {
        permanent ? permanentDelete(paths: paths) : moveToTrash(paths: paths)
    }

    public static func moveToTrash(paths: [String]) -> DeleteResult {
        var deleted: [String] = []; var failed: [(path: String, reason: String)] = []
        for path in paths {
            guard SafetyPolicy.canDelete(path) else { failed.append((path, "Güvenlik politikası tarafından engellendi")); continue }
            #if os(macOS)
            do { _ = try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil); deleted.append(path) }
            catch { failed.append((path, error.localizedDescription)) }
            #else
            failed.append((path, "Çöp kutusu yalnızca macOS'ta desteklenir"))
            #endif
        }
        return DeleteResult(deleted: deleted, failed: failed)
    }

    public static func permanentDelete(paths: [String]) -> DeleteResult {
        var deleted: [String] = []; var failed: [(path: String, reason: String)] = []
        for path in paths {
            guard SafetyPolicy.canDelete(path) else { failed.append((path, "Güvenlik politikası tarafından engellendi")); continue }
            do { try FileManager.default.removeItem(atPath: path); deleted.append(path) }
            catch { failed.append((path, error.localizedDescription)) }
        }
        return DeleteResult(deleted: deleted, failed: failed)
    }
}
