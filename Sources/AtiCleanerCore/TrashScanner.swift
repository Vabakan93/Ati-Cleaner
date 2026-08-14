import Foundation
#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

public struct TrashLocation: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let url: URL
    public let isExternal: Bool
    public init(name: String, url: URL, isExternal: Bool) { self.id=url.path; self.name=name; self.url=url; self.isExternal=isExternal }
}

public enum TrashScanner {
    public static func locations(includeExternal: Bool) -> [TrashLocation] {
        var out=[TrashLocation(name:"Mac Çöp Kutusu", url:FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"), isExternal:false)]
        guard includeExternal else { return out }
        let uid=getuid()
        if let volumes=try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath:"/Volumes"), includingPropertiesForKeys:[.volumeIsRemovableKey], options:[.skipsHiddenFiles]) {
            for vol in volumes {
                if SafetyPolicy.isExcludedVolume(vol.path) { continue }
                let trash=vol.appendingPathComponent(".Trashes/\(uid)")
                if FileManager.default.fileExists(atPath: trash.path) { out.append(.init(name:vol.lastPathComponent,url:trash,isExternal:true)) }
            }
        }
        return out
    }
    public static func items(includeExternal: Bool) -> [CleanableItem] {
        var out:[CleanableItem]=[]
        for loc in locations(includeExternal: includeExternal) {
            guard let children=try? FileManager.default.contentsOfDirectory(at:loc.url,includingPropertiesForKeys:[.isDirectoryKey,.fileSizeKey,.contentModificationDateKey],options:[.skipsHiddenFiles]) else { continue }
            for child in children {
                let v=try? child.resourceValues(forKeys:[.isDirectoryKey,.fileSizeKey,.contentModificationDateKey])
                let isDir=v?.isDirectory ?? false
                let size=isDir ? FileUtilities.recursiveSize(of:child) : Int64(v?.fileSize ?? 0)
                out.append(.init(name:child.lastPathComponent,path:child.path,size:size,isDirectory:isDir,date:v?.contentModificationDate,isSelected:false))
            }
        }
        return out
    }
}
