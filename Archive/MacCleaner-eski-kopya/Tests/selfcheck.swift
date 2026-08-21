import Foundation

@main
struct SelfCheck {
    static func main() {
        let none: () -> Bool = { false }

        print("=== 1) Sistem Copu (JunkScanner) ===")
        let junk = JunkScanner()
        let junkGroups = junk.defaultGroups().map { group -> (name: String, items: [CleanableItem]) in
            let items = junk.scanGroup(group, progress: { _ in }, isCancelled: none)
            return (group.name, items)
        }
        let junkTotal = junkGroups.reduce(Int64(0)) { $0 + $1.items.reduce(Int64(0)) { $0 + $1.size } }
        print("Grup sayisi: \(junkGroups.count), toplam: \(junkTotal) bytes (\(junkTotal/1024/1024) MB)")
        for g in junkGroups {
            let size = g.items.reduce(Int64(0)) { $0 + $1.size }
            print("  - \(g.name): \(size/1024/1024) MB, \(g.items.count) oge")
        }

        print("=== 2) Buyuk Dosyalar (100MB) ===")
        let large = LargeFileScanner().scan(
            root: URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path),
            minSize: 100 * 1024 * 1024,
            progress: { _ in },
            isCancelled: none
        )
        print("Sonuc: \(large.count) dosya, toplam \(large.reduce(0) { $0 + $1.size }/1024/1024) MB")
        for f in large.prefix(6) { print("  - \(f.name): \(f.size/1024/1024) MB") }

        print("=== 3) Cift Dosyalar (5MB) ===")
        let dups = DuplicateScanner().scan(
            root: URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path),
            minSize: 5 * 1024 * 1024,
            progress: { _ in },
            isCancelled: none
        )
        print("Grup: \(dups.count), dosya: \(dups.reduce(0) { $0 + $1.files.count })")
        for g in dups.prefix(4) { print("  - \(g.fileSize/1024/1024) MB, \(g.files.count) kopya: \(g.files.first?.path ?? "?")") }

        print("=== 4) Cop Kutusu (ev) ===")
        let trashResult = TrashScanner().scan(includeExternal: false, progress: { _ in }, isCancelled: none)
        print("Oge: \(trashResult.items.count), engelli: \(trashResult.inaccessibleRoots), uyari: \(trashResult.volumeWarnings)")

        print("=== 5) Uygulamalar (AppScanner) ===")
        let apps = AppScanner().scanApps(progress: { _ in }, isCancelled: none)
        print("Uygulama: \(apps.count)")

        print("=== 6) Bellek ===")
        if let mem = MemoryInfo.currentStatus() {
            print("Toplam: \(mem.total/1024/1024) MB, kullanilan: \(mem.used/1024/1024) MB (%\(Int(mem.usedPercentage*100)))")
        } else {
            print("Bellek bilgisi alinamadi (NULL)")
        }

        print("=== 7) Disk ===")
        if let disk = DiskUsage.currentStatus() {
            print("Kullanilan: \(disk.used/1024/1024/1024) GB, bos: \(disk.available/1024/1024/1024) GB")
        } else {
            print("Disk bilgisi alinamadi (NULL)")
        }

        print("TUM MODULLER TAMAM")
    }
}