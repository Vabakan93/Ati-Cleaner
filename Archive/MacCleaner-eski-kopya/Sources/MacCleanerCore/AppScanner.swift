import Foundation

public struct LeftoverItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let isDirectory: Bool
    public var isSelected: Bool

    public init(name: String, path: String, size: Int64, isDirectory: Bool, isSelected: Bool = true) {
        self.id = path
        self.name = name
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
        self.isSelected = isSelected
    }
}

public struct AppInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let bundleID: String
    public let version: String?
    public let size: Int64
    public let modifiedDate: Date?
    public let isSystem: Bool
    public var leftovers: [LeftoverItem]
    public var isSelected: Bool
    public var isExpanded: Bool

    public init(name: String, path: String, bundleID: String, version: String?, size: Int64, modifiedDate: Date?, isSystem: Bool) {
        self.id = path
        self.name = name
        self.path = path
        self.bundleID = bundleID
        self.version = version
        self.size = size
        self.modifiedDate = modifiedDate
        self.isSystem = isSystem
        self.leftovers = []
        self.isSelected = false
        self.isExpanded = false
    }

    public var totalSize: Int64 { size + leftovers.filter(\.isSelected).reduce(0) { $0 + $1.size } }
}

public struct AppScanner: Sendable {

    public init() {}

    public var appRoots: [String] {
        var roots = ["/Applications"]
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let userApps = "\(home)/Applications"
        if FileManager.default.fileExists(atPath: userApps) {
            roots.append(userApps)
        }
        return roots
    }

    public func scanApps(
        progress: @escaping (ScanProgress) -> Void,
        isCancelled: @escaping () -> Bool
    ) -> [AppInfo] {
        var apps: [AppInfo] = []
        let fm = FileManager.default

        for root in appRoots {
            let rootURL = URL(fileURLWithPath: root)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else { continue }

            let entries = FileUtils.existingChildren(of: rootURL)
                .filter { $0.pathExtension == "app" || $0.pathExtension == "appex" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            for (index, appURL) in entries.enumerated() {
                if isCancelled() { break }
                progress(ScanProgress(
                    phase: "Uygulamalar taranıyor…",
                    processed: Int64(index),
                    total: Int64(entries.count),
                    detail: appURL.lastPathComponent
                ))

                let bundle = Bundle(url: appURL)
                let bundleID = bundle?.bundleIdentifier ?? appURL.deletingPathExtension().lastPathComponent
                let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? appURL.deletingPathExtension().lastPathComponent
                let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                let isSystem = bundleID.hasPrefix("com.apple.") && root == "/Applications"
                let size = FileUtils.recursiveSize(of: appURL, isCancelled: isCancelled)
                let values = try? appURL.resourceValues(forKeys: [.contentModificationDateKey])

                var app = AppInfo(
                    name: name,
                    path: appURL.path,
                    bundleID: bundleID,
                    version: version,
                    size: size,
                    modifiedDate: values?.contentModificationDate,
                    isSystem: isSystem
                )
                app.leftovers = findLeftovers(appName: name, bundleID: bundleID, isCancelled: isCancelled)
                apps.append(app)
            }
        }

        progress(ScanProgress(
            phase: "Tarama tamamlandı",
            processed: Int64(apps.count),
            total: Int64(apps.count),
            detail: nil
        ))

        return apps.sorted { $0.size > $1.size }
    }

    public func findLeftovers(
        appName: String,
        bundleID: String,
        isCancelled: @escaping () -> Bool
    ) -> [LeftoverItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let library = "\(home)/Library"
        var candidates: [LeftoverItem] = []

        let paths: [(String, String)] = [
            ("Uygulama Destek Dosyaları", "\(library)/Application Support/\(appName)"),
            ("Önbellekler", "\(library)/Caches/\(appName)"),
            ("Önbellekler", "\(library)/Caches/\(bundleID)"),
            ("Tercihler", "\(library)/Preferences/\(bundleID).plist"),
            ("Günlükler", "\(library)/Logs/\(appName)"),
            ("Kayıtlı Durum", "\(library)/Saved Application State/\(bundleID).savedState"),
            ("Sandbox Verileri", "\(library)/Containers/\(bundleID)"),
            ("WebKit", "\(library)/WebKit/\(bundleID)"),
            ("HTTP Depolama", "\(library)/HTTPStorages/\(bundleID)"),
            ("Başlangıç Aracı", "\(library)/LaunchAgents/\(bundleID).plist"),
            ("Scriptler", "\(library)/Application Scripts/\(bundleID)")
        ]

        for (label, path) in paths {
            if isCancelled() { break }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { continue }
            let size = FileUtils.recursiveSize(of: URL(fileURLWithPath: path), isCancelled: isCancelled)
            candidates.append(LeftoverItem(
                name: label,
                path: path,
                size: size,
                isDirectory: isDir.boolValue
            ))
        }

        let groupContainers = "\(library)/Group Containers"
        let groups = FileUtils.existingChildren(of: URL(fileURLWithPath: groupContainers))
            .filter { $0.lastPathComponent.hasPrefix(bundleID) }
        for group in groups {
            if isCancelled() { break }
            let size = FileUtils.recursiveSize(of: group, isCancelled: isCancelled)
            candidates.append(LeftoverItem(
                name: "Grup Konteyneri",
                path: group.path,
                size: size,
                isDirectory: true
            ))
        }

        return candidates.sorted { $0.size > $1.size }
    }
}