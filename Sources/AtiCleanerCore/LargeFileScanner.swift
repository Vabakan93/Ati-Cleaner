import Foundation

public struct LargeFileScanner: Sendable {
    public init() {}
    public func scan(root: URL, minSize: Int64, progress: @escaping @Sendable (ScanProgress) -> Void, isCancelled: @escaping @Sendable () -> Bool) -> [LargeFileResult] {
        guard SafetyPolicy.canScan(root.path) else { return [] }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { url, error in
            progress(ScanProgress(phase: "Erişim sınırlı", detail: "\(url.path): \(error.localizedDescription)")); return true
        }) else { return [] }
        var out: [LargeFileResult] = []; var n: Int64 = 0
        for case let child as URL in e {
            if isCancelled() { break }
            if SafetyPolicy.isExcludedVolume(child.path) { e.skipDescendants(); continue }
            if SafetyPolicy.shouldSkipDescendants(of: child.path) { e.skipDescendants(); continue }
            if SafetyPolicy.shouldSkipDuringUserScan(child.path) { continue }
            guard let v = try? child.resourceValues(forKeys: keys), v.isSymbolicLink != true, v.isRegularFile == true else { continue }
            n += 1
            let size = Int64(v.fileSize ?? 0)
            if size >= minSize { out.append(.init(path: child.path, size: size, date: v.contentModificationDate)) }
            if n % 250 == 0 { progress(.init(phase: "Dosyalar taranıyor…", processed: n, detail: child.path)) }
        }
        return out.sorted { $0.size > $1.size }
    }
}
