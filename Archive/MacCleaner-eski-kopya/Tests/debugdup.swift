import Foundation


struct DebugDup {
    static func main() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey, .contentModificationDateKey]
        let root = URL(fileURLWithPath: NSHomeDirectory())
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else { print("ENUMERATOR YOK"); return }

        var count = 0
        var found: [String] = []
        for case let child as URL in enumerator {
            count += 1
            if child.path.contains("Group Containers") && child.path.contains("a90867c4") {
                found.append(child.path)
            }
        }
        print("Toplam enumerasyon: \(count) oge")
        print("Aranan dosyalar: \(found.count)")
        for p in found {
            let vals = try? URL(fileURLWithPath: p).resourceValues(forKeys: Set(keys))
            print("  \(p)")
            print("  regular=\(vals?.isRegularFile ?? false) size=\(vals?.fileSize ?? -1) symlink=\(vals?.isSymbolicLink ?? false)")
        }
    }
}

DebugDup.main()

