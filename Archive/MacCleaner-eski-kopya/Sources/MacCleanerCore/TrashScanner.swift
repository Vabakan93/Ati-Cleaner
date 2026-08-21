import Foundation

public struct TrashScanResult: Sendable {
    public let items: [CleanableItem]
    public let inaccessibleRoots: [String]
    public let volumeWarnings: [String]

    public init(items: [CleanableItem], inaccessibleRoots: [String], volumeWarnings: [String]) {
        self.items = items
        self.inaccessibleRoots = inaccessibleRoots
        self.volumeWarnings = volumeWarnings
    }
}

public struct TrashScanner: Sendable {

    public init() {}

    public func trashRoots(includeExternal: Bool = false) -> [URL] {
        var roots = [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")]

        guard includeExternal else { return roots }

        if let volumes = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: nil,
            options: []
        ) {
            for volume in volumes {
                let trash = volume.appendingPathComponent(".Trashes")
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: trash.path, isDirectory: &isDir), isDir.boolValue {
                    roots.append(trash)
                }
            }
        }
        return roots
    }

    public func scan(
        includeExternal: Bool = false,
        progress: @escaping (ScanProgress) -> Void,
        isCancelled: @escaping () -> Bool
    ) -> TrashScanResult {
        var items: [CleanableItem] = []
        var inaccessible: [String] = []
        var volumeWarnings: [String] = []
        let roots = trashRoots(includeExternal: includeExternal)
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path

        Diagnostics.log("=== ÇÖP KUTUSU TARAMASI BAŞLADI (harici diskler: \(includeExternal ? "DAHİL" : "HARİÇ")) ===")
        Diagnostics.log("FDA (probe): \(AccessCheck.hasFullDiskAccess() ? "AÇIK" : "KAPALI")")
        Diagnostics.log("Trash okunabilir (probe): \(AccessCheck.isTrashReadable() ? "EVET" : "HAYIR")")

        if let homeRoot = roots.first {
            Diagnostics.log("du -sk \(homeRoot.path) → \(TrashScanner.duSize(homeRoot.path) ?? "hata")")
            Diagnostics.log("readdir \(homeRoot.path) → \(TrashScanner.rawListing(homeRoot.path))")
        }

        for root in roots {
            if isCancelled() { break }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
                Diagnostics.log("Kök yok/klasör değil: \(root.path)")
                continue
            }

            let children: [URL]
            do {
                children = try FileManager.default.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: nil,
                    options: []
                )
                Diagnostics.log("OK (\(children.count) öğe): \(root.path)")
            } catch {
                if root.path.hasPrefix(homePath) {
                    inaccessible.append(root.path)
                } else {
                    volumeWarnings.append(root.path)
                }
                Diagnostics.log("ENGEL: \(root.path) — \(error.localizedDescription)")
                continue
            }

            for child in children {
                if isCancelled() { break }
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
                let size = FileUtils.recursiveSize(of: child, isCancelled: isCancelled)
                items.append(CleanableItem(
                    name: child.lastPathComponent,
                    path: child.path,
                    size: size,
                    isDirectory: values?.isDirectory ?? false,
                    date: values?.contentModificationDate
                ))
            }
        }

        progress(ScanProgress(
            phase: "Çöp kutusu taranıyor…",
            processed: Int64(items.count),
            total: -1,
            detail: nil
        ))

        Diagnostics.log("SONUÇ: \(items.count) öğe, \(inaccessible.count) engelli kök: \(inaccessible), \(volumeWarnings.count) harici disk uyarısı")
        return TrashScanResult(
            items: items.sorted { $0.size > $1.size },
            inaccessibleRoots: inaccessible,
            volumeWarnings: volumeWarnings
        )
    }

    public static func duSize(_ path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try? process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func rawListing(_ path: String) -> [String] {
        var names: [String] = []
        guard let dir = opendir(path) else { return [] }
        defer { closedir(dir) }
        while let entry = readdir(dir) {
            let name = withUnsafeBytes(of: entry.pointee.d_name) { raw -> String in
                guard let base = raw.baseAddress else { return "" }
                return String(cString: base.bindMemory(to: Int8.self, capacity: raw.count))
            }
            if !name.isEmpty { names.append(name) }
        }
        return names
    }
}