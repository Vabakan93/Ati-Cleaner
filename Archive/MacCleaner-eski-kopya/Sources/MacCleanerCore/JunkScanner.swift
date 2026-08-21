import Foundation

public struct JunkScanner: Sendable {

    public init() {}

    public var home: String { FileManager.default.homeDirectoryForCurrentUser.path }

    public func defaultGroups() -> [JunkGroup] {
        [
            JunkGroup(
                id: "caches",
                name: "Önbellek Dosyaları",
                iconName: "internaldrive",
                locations: [
                    JunkLocation(name: "Kullanıcı Önbellekleri", path: "\(home)/Library/Caches"),
                    JunkLocation(name: "Sistem Önbellekleri", path: "/Library/Caches"),
                    JunkLocation(name: "Uygulama Sandbox Önbellekleri", path: "\(home)/Library/Containers", kind: .containerCaches)
                ]
            ),
            JunkGroup(
                id: "logs",
                name: "Günlük Dosyaları",
                iconName: "doc.text",
                locations: [
                    JunkLocation(name: "Kullanıcı Günlükleri", path: "\(home)/Library/Logs"),
                    JunkLocation(name: "Sistem Günlükleri", path: "/Library/Logs"),
                    JunkLocation(name: "Uygulama Sandbox Günlükleri", path: "\(home)/Library/Containers", kind: .containerLogs)
                ]
            ),
            JunkGroup(
                id: "temp",
                name: "Geçici Dosyalar",
                iconName: "clock",
                locations: [
                    JunkLocation(name: "Sistem Geçici Klasörü", path: NSTemporaryDirectory()),
                    JunkLocation(name: "/tmp", path: "/tmp")
                ]
            ),
            JunkGroup(
                id: "crash",
                name: "Hata Raporları",
                iconName: "exclamationmark.triangle",
                locations: [
                    JunkLocation(name: "Kullanıcı Hata Raporları", path: "\(home)/Library/Logs/DiagnosticReports"),
                    JunkLocation(name: "Sistem Hata Raporları", path: "/Library/Logs/DiagnosticReports")
                ]
            ),
            JunkGroup(
                id: "downloads",
                name: "Eski İndirmeler",
                iconName: "arrow.down.circle",
                locations: [
                    JunkLocation(name: "30 günden eski indirmeler", path: "\(home)/Downloads", kind: .oldDownloads)
                ]
            ),
            JunkGroup(
                id: "dev",
                name: "Geliştirici Çöpleri",
                iconName: "hammer",
                locations: [
                    JunkLocation(name: "Xcode DerivedData", path: "\(home)/Library/Developer/Xcode/DerivedData", kind: .derivedData),
                    JunkLocation(name: "Simülatör Önbellekleri", path: "\(home)/Library/Developer/CoreSimulator/Caches", kind: .derivedData)
                ]
            )
        ]
    }

    public func scanGroup(
        _ group: JunkGroup,
        progress: @escaping (ScanProgress) -> Void,
        onPermissionDenied: @escaping (String) -> Void = { _ in },
        isCancelled: @escaping () -> Bool
    ) -> [CleanableItem] {
        var items: [CleanableItem] = []
        var processed = 0

        for location in group.locations {
            if isCancelled() { break }
            progress(ScanProgress(
                phase: "\(location.name) taranıyor…",
                processed: Int64(processed),
                total: Int64(group.locations.count),
                detail: location.path
            ))
            items.append(contentsOf: scanLocation(location, onPermissionDenied: onPermissionDenied, isCancelled: isCancelled))
            processed += 1
            progress(ScanProgress(
                phase: "\(location.name) tamamlandı",
                processed: Int64(processed),
                total: Int64(group.locations.count),
                detail: nil
            ))
        }

        return items.sorted { $0.size > $1.size }
    }

    private func scanLocation(
        _ location: JunkLocation,
        onPermissionDenied: (String) -> Void,
        isCancelled: @escaping () -> Bool
    ) -> [CleanableItem] {
        let fm = FileManager.default
        var items: [CleanableItem] = []

        switch location.kind {
        case .directory, .derivedData:
            let url = URL(fileURLWithPath: location.path)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: location.path, isDirectory: &isDir), isDir.boolValue else { return [] }
            let children: [URL]
            do {
                children = try fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: []
                )
            } catch {
                onPermissionDenied(location.path)
                return []
            }
            for child in children {
                if isCancelled() { break }
                let size = FileUtils.recursiveSize(of: child, isCancelled: isCancelled)
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
                items.append(CleanableItem(
                    name: child.lastPathComponent,
                    path: child.path,
                    size: size,
                    isDirectory: values?.isDirectory ?? false,
                    date: values?.contentModificationDate
                ))
            }

        case .containerCaches, .containerLogs:
            let subPath = location.kind == .containerCaches ? "Data/Library/Caches" : "Data/Library/Logs"
            let containersRoot = URL(fileURLWithPath: location.path)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: location.path, isDirectory: &isDir), isDir.boolValue else { return [] }
            let containers: [URL]
            do {
                containers = try fm.contentsOfDirectory(
                    at: containersRoot,
                    includingPropertiesForKeys: nil,
                    options: []
                )
            } catch {
                onPermissionDenied(location.path)
                return []
            }

            for container in containers where container.lastPathComponent.contains(".") {
                if isCancelled() { break }
                let target = container.appendingPathComponent(subPath)
                var targetIsDir: ObjCBool = false
                guard fm.fileExists(atPath: target.path, isDirectory: &targetIsDir), targetIsDir.boolValue else { continue }
                let size = FileUtils.recursiveSize(of: target, isCancelled: isCancelled)
                items.append(CleanableItem(
                    name: container.lastPathComponent,
                    path: target.path,
                    size: size,
                    isDirectory: true
                ))
            }

        case .oldDownloads:
            let url = URL(fileURLWithPath: location.path)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: location.path, isDirectory: &isDir), isDir.boolValue else { return [] }
            let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
            let children: [URL]
            do {
                children = try fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: []
                )
            } catch {
                onPermissionDenied(location.path)
                return []
            }
            for child in children {
                if isCancelled() { break }
                let values = try? child.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
                guard let date = values?.contentModificationDate, date < cutoff else { continue }
                items.append(CleanableItem(
                    name: child.lastPathComponent,
                    path: child.path,
                    size: Int64(values?.fileSize ?? 0),
                    isDirectory: false,
                    date: date
                ))
            }
        }

        return items
    }
}
