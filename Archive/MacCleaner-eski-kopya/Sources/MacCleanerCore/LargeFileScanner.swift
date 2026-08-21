import Foundation

public struct LargeFileResult: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let date: Date?
    public var isSelected: Bool

    public init(name: String, path: String, size: Int64, date: Date?, isSelected: Bool = true) {
        self.id = path
        self.name = name
        self.path = path
        self.size = size
        self.date = date
        self.isSelected = isSelected
    }
}

public struct LargeFileScanner: Sendable {

    public init() {}

    public func scan(
        root: URL,
        minSize: Int64,
        progress: @escaping (ScanProgress) -> Void,
        isCancelled: @escaping () -> Bool
    ) -> [LargeFileResult] {
        let fm = FileManager.default
        var results: [LargeFileResult] = []
        var processed: Int64 = 0

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .fileSizeKey,
            .isDirectoryKey,
            .isPackageKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey
        ]

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else { return [] }

        for case let child as URL in enumerator {
            if isCancelled() { break }
            processed += 1

            if FileUtils.isSystemProtected(child.path) { continue }

            let values = (try? child.resourceValues(forKeys: Set(keys))) ?? URLResourceValues()
            if values.isSymbolicLink == true { continue }

            var size: Int64 = 0
            var isBundle = false
            var date = values.contentModificationDate

            if values.isPackage == true {
                isBundle = true
                size = FileUtils.recursiveSize(of: child, isCancelled: isCancelled)
                if let mod = values.contentModificationDate { date = mod }
            } else if values.isRegularFile == true {
                size = Int64(values.fileSize ?? 0)
            }

            if size >= minSize {
                results.append(LargeFileResult(
                    name: child.lastPathComponent,
                    path: child.path,
                    size: size,
                    date: date,
                    isSelected: true
                ))
            }

            if processed % 100 == 0 {
                progress(ScanProgress(
                    phase: isBundle ? "Büyük dosyalar taranıyor…" : "Dosyalar taranıyor…",
                    processed: processed,
                    total: -1,
                    detail: child.path
                ))
            }
        }

        progress(ScanProgress(
            phase: "Tarama tamamlandı",
            processed: processed,
            total: -1,
            detail: nil
        ))

        return results.sorted { $0.size > $1.size }
    }
}