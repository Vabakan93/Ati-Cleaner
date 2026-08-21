import Foundation

struct DebugDir {
    static func main() {
        let fm = FileManager.default
        let base = NSHomeDirectory() + "/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media"
        let dirs = ["236038719033437@lid/2/c", "239896002306105@lid/d/e", "54551101071360@lid/a/9"]
        for d in dirs {
            let path = base + "/" + d
            let items = (try? fm.contentsOfDirectory(atPath: path)) ?? []
            print("\(d): \(items.count) oge")
            for i in items { print("   - \(i)") }
        }
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let url = URL(fileURLWithPath: base + "/236038719033437@lid/2/c")
        var count = 0
        if let en = fm.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsPackageDescendants, .skipsHiddenFiles]) {
            for case let child as URL in en {
                count += 1
                let v = try? child.resourceValues(forKeys: Set(keys))
                print("enumerated: \(child.lastPathComponent) regular=\(v?.isRegularFile ?? false) size=\(v?.fileSize ?? -1)")
            }
        }
        print("enumerator sayisi: \(count)")
    }
}

DebugDir.main()