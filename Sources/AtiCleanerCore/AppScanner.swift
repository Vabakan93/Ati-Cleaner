import Foundation

public enum AppScanner {
    public static func installedApps() -> [InstalledApp] {
        let fm=FileManager.default
        let roots=[URL(fileURLWithPath:"/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        var out:[InstalledApp]=[]
        for root in roots {
            guard let apps=try? fm.contentsOfDirectory(at:root,includingPropertiesForKeys:[.isDirectoryKey],options:[.skipsHiddenFiles]) else { continue }
            for app in apps where app.pathExtension.lowercased()=="app" {
                let bundle=Bundle(url:app)
                let name=(bundle?.object(forInfoDictionaryKey:"CFBundleDisplayName") as? String) ?? (bundle?.object(forInfoDictionaryKey:"CFBundleName") as? String) ?? app.deletingPathExtension().lastPathComponent
                out.append(.init(name:name,path:app.path,bundleIdentifier:bundle?.bundleIdentifier,size:FileUtilities.recursiveSize(of:app)))
            }
        }
        return Array(Set(out)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
