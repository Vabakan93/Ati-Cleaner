import Foundation

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

    public static func moveToTrash(paths: [String]) -> (succeeded: Int, failed: [String]) {
        var ok = 0; var failed: [String] = []
        for path in paths {
            guard SafetyPolicy.canDelete(path) else { failed.append("Blocked by safety policy: \(path)"); continue }
            #if os(macOS)
            do { _ = try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil); ok += 1 }
            catch { failed.append("\(path): \(error.localizedDescription)") }
            #else
            failed.append("Trash operation is supported on macOS only: \(path)")
            #endif
        }
        return (ok, failed)
    }
}
