import Foundation
import CryptoKit

public struct DuplicateFile: Identifiable, Hashable, Sendable {
    public let id: String
    public let path: String
    public let size: Int64
    public let date: Date?
    public var isSelected: Bool

    public init(path: String, size: Int64, date: Date?, isSelected: Bool = true) {
        self.id = path
        self.path = path
        self.size = size
        self.date = date
        self.isSelected = isSelected
    }
}

public struct DuplicateGroup: Identifiable, Sendable {
    public let id: String
    public let hash: String
    public let fileSize: Int64
    public var files: [DuplicateFile]
    public var isExpanded: Bool = false

    public init(hash: String, fileSize: Int64, files: [DuplicateFile]) {
        self.id = hash
        self.hash = hash
        self.fileSize = fileSize
        self.files = files
    }

    public var wasteSize: Int64 { fileSize * Int64(max(files.count - 1, 0)) }
    public var selectedSize: Int64 { files.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    public var selectedCount: Int { files.filter(\.isSelected).count }
}

public struct DuplicateScanner: Sendable {

    public init() {}

    public func scan(
        root: URL,
        minSize: Int64,
        progress: @escaping (ScanProgress) -> Void,
        isCancelled: @escaping () -> Bool
    ) -> [DuplicateGroup] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey, .contentModificationDateKey]

        var buckets: [Int64: [URL]] = [:]
        var processed: Int64 = 0
        var bytesToHash: Int64 = 0

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else { return [] }

        for case let child as URL in enumerator {
            if isCancelled() { return [] }
            let path = child.path
            if path.contains("/.Trash") || path.contains("/.Trashes") { continue }
            if FileUtils.isSystemProtected(path) { continue }

            let values = (try? child.resourceValues(forKeys: Set(keys))) ?? URLResourceValues()
            if values.isSymbolicLink == true || values.isRegularFile != true { continue }
            let size = Int64(values.fileSize ?? 0)
            guard size >= minSize else { continue }

            buckets[size, default: []].append(child)
            bytesToHash += size
            processed += 1

            if processed % 500 == 0 {
                progress(ScanProgress(
                    phase: "Dosyalar listeleniyor…",
                    processed: processed,
                    total: -1,
                    detail: child.path
                ))
            }
        }

        progress(ScanProgress(
            phase: "İçerikler karşılaştırılıyor…",
            processed: 0,
            total: max(bytesToHash, 1),
            detail: nil
        ))

        var byHash: [String: [DuplicateFile]] = [:]
        var hashedBytes: Int64 = 0

        for (size, urls) in buckets where urls.count > 1 {
            for url in urls {
                if isCancelled() { return [] }
                let hash = sha256(of: url, size: size, isCancelled: isCancelled)
                hashedBytes += size
                if let hash {
                    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                    byHash[hash, default: []].append(DuplicateFile(
                        path: url.path,
                        size: size,
                        date: values?.contentModificationDate
                    ))
                }
                if hashedBytes % 100_000_000 < size {
                    progress(ScanProgress(
                        phase: "İçerikler karşılaştırılıyor…",
                        processed: hashedBytes,
                        total: max(bytesToHash, 1),
                        detail: url.path
                    ))
                }
            }
        }

        var groups: [DuplicateGroup] = []
        for (hash, files) in byHash where files.count > 1 {
            var groupFiles = files.sorted { $0.path < $1.path }
            for index in groupFiles.indices { groupFiles[index].isSelected = index > 0 }
            groups.append(DuplicateGroup(hash: hash, fileSize: files[0].size, files: groupFiles))
        }

        progress(ScanProgress(
            phase: "Tarama tamamlandı",
            processed: hashedBytes,
            total: max(bytesToHash, 1),
            detail: nil
        ))

        return groups.sorted { $0.wasteSize > $1.wasteSize }
    }

    private func sha256(of url: URL, size: Int64, isCancelled: @escaping () -> Bool) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        let bufferSize = 1_048_576
        var remaining = size

        while remaining > 0 {
            if isCancelled() { return nil }
            let length = Int(min(Int64(bufferSize), remaining))
            let data = handle.readData(ofLength: length)
            guard !data.isEmpty else { break }
            hasher.update(data: data)
            remaining -= Int64(data.count)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}