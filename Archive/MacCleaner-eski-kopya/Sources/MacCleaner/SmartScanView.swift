import SwiftUI
import MacCleanerCore

@MainActor
final class SmartScanViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var progress = ScanProgress(phase: "Hazır", processed: 0, total: -1)
    @Published var junkGroups: [JunkGroup] = []
    @Published var appsSize: Int64 = 0
    @Published var trashItems: [CleanableItem] = []
    @Published var freedBytes: Int64?
    @Published var errorMessage: String?
    @Published var hasScanned = false

    private var token = CancellationToken()
    private let scanner = JunkScanner()

    var junkSize: Int64 { junkGroups.reduce(0) { $0 + $1.totalSize } }
    var trashSize: Int64 { trashItems.reduce(0) { $0 + $1.size } }
    var cleanableSize: Int64 { junkSize }
    var cleanableCount: Int { junkGroups.reduce(0) { $0 + $1.itemCount } }

    func scan() {
        guard !isScanning && !isCleaning else { return }
        isScanning = true
        hasScanned = false
        freedBytes = nil
        errorMessage = nil
        token = CancellationToken()
        let token = self.token
        let scanner = self.scanner
        var groups = scanner.defaultGroups()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            for index in groups.indices {
                if token.isCancelled { break }
                let items = scanner.scanGroup(groups[index]) { p in
                    DispatchQueue.main.async {
                        self.progress = p
                    }
                } isCancelled: {
                    token.isCancelled
                }
                groups[index].items = items
                DispatchQueue.main.async {
                    self.junkGroups = groups
                    self.progress = ScanProgress(
                        phase: "Sistem çöpü: \(self.junkSize == 0 ? "0" : formattedByteCount(self.junkSize)) bulundu",
                        processed: Int64(index + 1),
                        total: Int64(groups.count),
                        detail: nil
                    )
                }
            }

            DispatchQueue.main.async {
                self.progress = ScanProgress(
                    phase: "Uygulamalar ölçülüyor…",
                    processed: 0,
                    total: -1,
                    detail: nil
                )
            }
            let apps = Self.measureApps(isCancelled: { token.isCancelled })

            DispatchQueue.main.async {
                self.appsSize = apps
                self.progress = ScanProgress(
                    phase: "Çöp kutusu taranıyor…",
                    processed: 0,
                    total: -1,
                    detail: nil
                )
            }
            let trash = TrashScanner().scan(includeExternal: false) { p in
                DispatchQueue.main.async {
                    self.progress = p
                }
            } isCancelled: {
                token.isCancelled
            }

            DispatchQueue.main.async {
                self.trashItems = trash.items
                self.isScanning = false
                self.hasScanned = true
                self.progress = ScanProgress(
                    phase: "Genel tarama tamamlandı",
                    processed: 1,
                    total: 1,
                    detail: nil
                )
            }
        }
    }

    func cancel() {
        token.cancel()
    }

    func clean() {
        guard !isCleaning, cleanableCount > 0 else { return }
        isCleaning = true
        errorMessage = nil
        token = CancellationToken()
        let token = self.token
        let permanent = UserDefaults.standard.bool(forKey: "permanentDelete")
        let paths = junkGroups.flatMap { $0.items }.map(\.path)
        let total = paths.count

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = FileUtils.deletePaths(paths: paths, permanent: permanent) { done, _, freed in
                DispatchQueue.main.async {
                    self.progress = ScanProgress(
                        phase: "Temizleniyor… \(done)/\(total)",
                        processed: Int64(done),
                        total: Int64(total),
                        detail: nil
                    )
                    self.freedBytes = freed
                }
            } isCancelled: {
                token.isCancelled
            }

            DispatchQueue.main.async {
                self.isCleaning = false
                self.freedBytes = result.freedBytes
                if result.failed > 0 {
                    self.errorMessage = "\(result.failed) öğe silinemedi: \(result.errors.prefix(3).joined(separator: " • "))"
                }
                for index in self.junkGroups.indices {
                    self.junkGroups[index].items.removeAll()
                }
            }
        }
    }

    nonisolated private static func measureApps(isCancelled: @escaping () -> Bool) -> Int64 {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var total: Int64 = 0
        for root in ["/Applications", "\(home)/Applications"] {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else { continue }
            let url = URL(fileURLWithPath: root)
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil, options: []
            ) else { continue }
            for app in children where app.pathExtension == "app" {
                if isCancelled() { break }
                total += FileUtils.recursiveSize(of: app, isCancelled: isCancelled)
            }
        }
        return total
    }
}

struct SmartScanCard: View {
    @ObservedObject var viewModel: SmartScanViewModel
    @State private var disk: DiskStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Genel Tarama")
                    .font(.title2.bold())
                Spacer()
                if let disk {
                    Text("\(formattedByteCount(disk.used)) kullanıldı · \(formattedByteCount(disk.available)) boş")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 28) {
                gauge
                legend
            }

            if viewModel.isScanning || viewModel.isCleaning {
                ScanningPanel(progress: viewModel.progress, onCancel: viewModel.cancel)
            } else if viewModel.hasScanned {
                HStack(spacing: 12) {
                    if let freed = viewModel.freedBytes {
                        Label("\(formattedByteCount(freed)) temizlendi", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if viewModel.cleanableSize > 0 {
                        Text("Temizlenebilir: \(formattedByteCount(viewModel.cleanableSize)) (\(viewModel.cleanableCount) öğe)")
                            .font(.headline)
                        Button {
                            viewModel.clean()
                        } label: {
                            Label("Temizle (\(formattedByteCount(viewModel.cleanableSize)))", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else {
                        Text("Temizlenecek çöp bulunamadı 🎉")
                            .foregroundStyle(.green)
                    }
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                Button {
                    viewModel.scan()
                } label: {
                    Label("Hepsini Tara", systemImage: "play.fill")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .onAppear {
            disk = DiskUsage.currentStatus()
        }
    }

    private var gauge: some View {
        let arcs = gaugeArcs
        return ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 30)

            ForEach(arcs) { arc in
                Circle()
                    .trim(from: arc.start, to: arc.end)
                    .stroke(arc.color, style: StrokeStyle(lineWidth: 30, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: arc.end)
            }

            VStack(spacing: 2) {
                Text(formattedByteCount(disk?.available ?? 0))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("boş alan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int((disk?.usedPercentage ?? 0) * 100))% kullanılıyor")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(width: 170, height: 170)
    }

    private struct GaugeArc: Identifiable {
        let id: String
        let start: Double
        let end: Double
        let color: Color
    }

    private var gaugeArcs: [GaugeArc] {
        let used = Double(disk?.used ?? 1)
        let segments = smartSegments(totalUsed: used)
        var start = 0.0
        var arcs: [GaugeArc] = []
        for segment in segments {
            let fraction = used > 0 ? Double(segment.size) / used : 0
            let end = min(start + fraction, 1)
            arcs.append(GaugeArc(id: segment.id, start: start, end: end, color: segment.color))
            start = end
        }
        return arcs
    }

    private var legend: some View {
        let used = Double(disk?.used ?? 1)
        let segments = smartSegments(totalUsed: used)
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(segments) { segment in
                HStack(spacing: 8) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 10, height: 10)
                    Text(segment.label)
                        .font(.caption)
                    Spacer()
                    Text(formattedByteCount(segment.size))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.gray.opacity(0.35))
                    .frame(width: 10, height: 10)
                Text("Boş alan")
                    .font(.caption)
                Spacer()
                Text(formattedByteCount(disk?.available ?? 0))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 180)
    }

    private struct SmartSegment: Identifiable {
        let id: String
        let label: String
        let size: Int64
        let color: Color
    }

    private func smartSegments(totalUsed: Double) -> [SmartSegment] {
        var segments = [
            SmartSegment(id: "junk", label: "Sistem çöpü", size: viewModel.junkSize, color: .orange),
            SmartSegment(id: "apps", label: "Uygulamalar", size: viewModel.appsSize, color: .blue),
            SmartSegment(id: "trash", label: "Çöp kutusu", size: viewModel.trashSize, color: .red)
        ]
        let sum = segments.reduce(0) { $0 + $1.size }
        let other = max(Int64(totalUsed) - sum, 0)
        segments.append(SmartSegment(id: "other", label: "Diğer dosyalar", size: other, color: .gray))
        return segments
    }
}