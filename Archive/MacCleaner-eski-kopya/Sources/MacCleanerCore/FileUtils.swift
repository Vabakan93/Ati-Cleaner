import Foundation

public enum FileUtils {

    public static let systemProtectedMarkers: [String] = [
        "/Library/Metadata/",                 // Spotlight Knowledge (arama indeksi)
        "/Library/Spotlight/",
        "/Library/Application Support/com.apple.spotlight/",
        "/Library/Knowledge/",                // Siri Önerileri
        "/Library/Suggestions/",
        "/Library/Application Support/CrashReporter/",
        "/Library/WebKit/",
        "/Library/HTTPStorages/"
    ]

    public static func isSystemProtected(_ path: String) -> Bool {
        systemProtectedMarkers.contains { path.contains($0) }
    }

    public static func recursiveSize(of url: URL, isCancelled: (() -> Bool)? = nil) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values?.fileSize ?? 0)
        }

        var total: Int64 = 0
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else { return 0 }

        for case let child as URL in enumerator {
            if let isCancelled, isCancelled() { break }
            let values = (try? child.resourceValues(forKeys: Set(keys))) ?? URLResourceValues()
            if values.isSymbolicLink == true { continue }
            if values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            }
        }
        return total
    }

    public static func itemFor(url: URL, size: Int64, date: Date? = nil) -> CleanableItem {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        let isDirectory = values?.isDirectory ?? false
        return CleanableItem(
            name: url.lastPathComponent,
            path: url.path,
            size: size,
            isDirectory: isDirectory,
            date: values?.contentModificationDate ?? date
        )
    }

    public static func existingChildren(of root: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: []
        )) ?? []
    }

    public static func deletePaths(
        paths: [String],
        permanent: Bool,
        progress: @escaping (Int, Int, Int64) -> Void,
        isCancelled: @escaping () -> Bool
    ) -> TrashResult {
        if permanent {
            return permanentlyDeleteItems(paths: paths, progress: progress, isCancelled: isCancelled)
        }
        return trashItems(paths: paths, progress: progress, isCancelled: isCancelled)
    }

    public static func trashItems(
        paths: [String],
        progress: @escaping (Int, Int, Int64) -> Void,
        isCancelled: @escaping () -> Bool
    ) -> TrashResult {
        let fm = FileManager.default
        var succeeded = 0
        var failed = 0
        var freed: Int64 = 0
        var errors: [String] = []
        let total = paths.count

        for (index, path) in paths.enumerated() {
            if isCancelled() { break }
            let url = URL(fileURLWithPath: path)
            if !fm.fileExists(atPath: path) { continue }
            let size = FileUtils.recursiveSize(of: url)
            do {
                try fm.trashItem(at: url, resultingItemURL: nil)
                succeeded += 1
                freed += size
            } catch {
                failed += 1
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
            progress(index + 1, total, freed)
        }
        return TrashResult(succeeded: succeeded, failed: failed, freedBytes: freed, errors: errors)
    }

    public static func permanentlyDeleteItems(
        paths: [String],
        progress: @escaping (Int, Int, Int64) -> Void,
        isCancelled: @escaping () -> Bool
    ) -> TrashResult {
        let fm = FileManager.default
        var succeeded = 0
        var failed = 0
        var freed: Int64 = 0
        var errors: [String] = []
        let total = paths.count

        for (index, path) in paths.enumerated() {
            if isCancelled() { break }
            let url = URL(fileURLWithPath: path)
            if !fm.fileExists(atPath: path) { continue }
            let size = FileUtils.recursiveSize(of: url)
            do {
                try fm.removeItem(at: url)
                succeeded += 1
                freed += size
            } catch {
                failed += 1
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
            progress(index + 1, total, freed)
        }
        return TrashResult(succeeded: succeeded, failed: failed, freedBytes: freed, errors: errors)
    }
}
