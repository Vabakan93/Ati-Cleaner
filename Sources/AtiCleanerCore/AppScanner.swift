import Foundation

public enum AppScanner {
    public static func installedApps() -> [InstalledApp] {
        let fm = FileManager.default
        let roots = [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        var bundles: [URL] = []
        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            for entry in entries {
                if entry.pathExtension.lowercased() == "app" {
                    bundles.append(entry)
                } else if (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    if let nested = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: [], options: [.skipsHiddenFiles]) {
                        for sub in nested where sub.pathExtension.lowercased() == "app" {
                            bundles.append(sub)
                        }
                    }
                }
            }
        }
        var out: [InstalledApp] = []
        for app in bundles {
            let bundle = Bundle(url: app)
            let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? app.deletingPathExtension().lastPathComponent
            out.append(.init(name: name, path: app.path, bundleIdentifier: bundle?.bundleIdentifier, size: FileUtilities.recursiveSize(of: app)))
        }
        return Array(Set(out)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
