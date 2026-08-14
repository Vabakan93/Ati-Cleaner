import Foundation

public struct JunkCategory: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let icon: String
    public let roots: [URL]
    public var items: [CleanableItem]
    public init(id: String, name: String, icon: String, roots: [URL], items: [CleanableItem] = []) {
        self.id=id; self.name=name; self.icon=icon; self.roots=roots; self.items=items
    }
    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

public struct JunkScanner: Sendable {
    public init() {}
    public func defaultCategories() -> [JunkCategory] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            .init(id:"caches", name:"Kullanıcı Önbellekleri", icon:"shippingbox", roots:[home.appendingPathComponent("Library/Caches")]),
            .init(id:"logs", name:"Günlükler", icon:"doc.text", roots:[home.appendingPathComponent("Library/Logs")]),
            .init(id:"saved", name:"Geçici Uygulama Kalıntıları", icon:"clock.arrow.circlepath", roots:[home.appendingPathComponent("Library/Saved Application State")])
        ]
    }
    public func scan(progress: @escaping @Sendable (ScanProgress)->Void, isCancelled: @escaping @Sendable ()->Bool) -> [JunkCategory] {
        var categories = defaultCategories(); let fm=FileManager.default
        for i in categories.indices {
            var items:[CleanableItem]=[]
            for root in categories[i].roots {
                guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey,.fileSizeKey,.contentModificationDateKey], options:[.skipsHiddenFiles]) else { continue }
                for child in children {
                    if isCancelled() { return categories }
                    if SafetyPolicy.shouldSkipDuringUserScan(child.path) { continue }
                    let v=try? child.resourceValues(forKeys:[.isDirectoryKey,.fileSizeKey,.contentModificationDateKey])
                    let isDir=v?.isDirectory ?? false
                    let size=isDir ? FileUtilities.recursiveSize(of: child, isCancelled:isCancelled) : Int64(v?.fileSize ?? 0)
                    items.append(.init(name:child.lastPathComponent,path:child.path,size:size,isDirectory:isDir,date:v?.contentModificationDate,isSelected:false))
                }
            }
            categories[i].items=items
            progress(.init(phase:"\(categories[i].name) tarandı",processed:Int64(i+1),total:Int64(categories.count)))
        }
        return categories
    }
}
