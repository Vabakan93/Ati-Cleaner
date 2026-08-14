import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public struct DuplicateScanner: Sendable {
    public init() {}

    public func scan(root: URL, minSize: Int64, progress: @escaping @Sendable (ScanProgress) -> Void, isCancelled: @escaping @Sendable () -> Bool) -> [DuplicateGroup] {
        guard SafetyPolicy.canScan(root.path) else { return [] }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var bySize: [Int64: [URL]] = [:]; var seen: Int64 = 0
        for case let child as URL in e {
            if isCancelled() { return [] }
            if SafetyPolicy.isExcludedVolume(child.path) { e.skipDescendants(); continue }
            if SafetyPolicy.isHomeLibrary(child.path) || SafetyPolicy.shouldSkipDescendants(of: child.path) { e.skipDescendants(); continue }
            if child.path.contains("/.Trash") || child.path.contains("/.Trashes") || SafetyPolicy.shouldSkipDuringUserScan(child.path) { continue }
            guard let v = try? child.resourceValues(forKeys: keys), v.isSymbolicLink != true, v.isRegularFile == true else { continue }
            let size = Int64(v.fileSize ?? 0); guard size >= minSize else { continue }
            bySize[size, default: []].append(child); seen += 1
            if seen % 500 == 0 { progress(.init(phase: "Aday dosyalar listeleniyor…", processed: seen, detail: child.path)) }
        }
        var groups: [DuplicateGroup] = []
        for (size, urls) in bySize where urls.count > 1 {
            var byHash: [String: [DuplicateFile]] = [:]
            for url in urls {
                if isCancelled() { return [] }
                guard let hash = digest(url) else { continue }
                let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                byHash[hash, default: []].append(.init(path: url.path, size: size, date: date))
            }
            for (hash, var files) in byHash where files.count > 1 {
                files.sort { $0.path < $1.path }
                for i in files.indices { files[i].isSelected = i > 0 }
                groups.append(.init(hash: hash, fileSize: size, files: files))
            }
        }
        return groups.sorted { $0.wasteSize > $1.wasteSize }
    }

    private func digest(_ url: URL) -> String? {
        #if canImport(CryptoKit)
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #else
        return nil
        #endif
    }
}
