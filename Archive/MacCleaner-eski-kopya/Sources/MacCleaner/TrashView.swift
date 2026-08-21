import SwiftUI
import MacCleanerCore

@MainActor
final class TrashViewModel: ObservableObject {
    @Published var items: [CleanableItem] = []
    @Published var isScanning = false
    @Published var isEmptying = false
    @Published var progress = ScanProgress(phase: "Hazır", processed: 0, total: -1)
    @Published var freedBytes: Int64?
    @Published var errorMessage: String?
    @Published var inaccessibleRoots: [String] = []
    @Published var volumeWarnings: [String] = []
    @Published var includeExternal = false
    @Published var fdaGranted = AccessCheck.hasFullDiskAccess()

    private var token = CancellationToken()

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        isEmptying = false
        freedBytes = nil
        errorMessage = nil
        inaccessibleRoots = []
        volumeWarnings = []
        fdaGranted = AccessCheck.hasFullDiskAccess()
        token = CancellationToken()
        let token = self.token
        let includeExternal = self.includeExternal

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = TrashScanner().scan(includeExternal: includeExternal) { p in
                DispatchQueue.main.async {
                    self.progress = p
                }
            } isCancelled: {
                token.isCancelled
            }

            DispatchQueue.main.async {
                self.items = result.items
                self.inaccessibleRoots = result.inaccessibleRoots
                self.volumeWarnings = result.volumeWarnings
                self.isScanning = false
                self.progress = ScanProgress(
                    phase: "\(result.items.count) öğe bulundu",
                    processed: Int64(result.items.count),
                    total: -1,
                    detail: nil
                )
            }
        }
    }

    func cancel() {
        token.cancel()
    }

    func empty() {
        guard !isEmptying, !items.isEmpty else { return }
        isEmptying = true
        errorMessage = nil
        token = CancellationToken()
        let token = self.token
        let paths = items.map(\.path)
        let total = paths.count

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = FileUtils.permanentlyDeleteItems(paths: paths) { done, _, freed in
                DispatchQueue.main.async {
                    self.progress = ScanProgress(
                        phase: "Boşaltılıyor… \(done)/\(total)",
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
                self.isEmptying = false
                self.freedBytes = result.freedBytes
                if result.failed > 0 {
                    self.errorMessage = "\(result.failed) öğe silinemedi: \(result.errors.prefix(3).joined(separator: " • "))"
                }
                self.items.removeAll()
                self.progress = ScanProgress(
                    phase: "Çöp kutusu boşaltıldı",
                    processed: Int64(result.succeeded),
                    total: Int64(total),
                    detail: nil
                )
            }
        }
    }
}

struct TrashView: View {
    @StateObject private var viewModel = TrashViewModel()
    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !viewModel.inaccessibleRoots.isEmpty {
                PermissionBanner(paths: viewModel.inaccessibleRoots, fdaGranted: viewModel.fdaGranted)
            }

            if !viewModel.volumeWarnings.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .foregroundStyle(.orange)
                    Text("Harici disk çöp kutularına erişilemedi: \(viewModel.volumeWarnings.map { URL(fileURLWithPath: $0).deletingLastPathComponent().lastPathComponent }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.isScanning {
                ScanningPanel(progress: viewModel.progress, onCancel: viewModel.cancel)
            } else if viewModel.isEmptying {
                ScanningPanel(progress: viewModel.progress, onCancel: viewModel.cancel)
            } else if viewModel.items.isEmpty {
                emptyState
            } else {
                results
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            "Çöp kutusundaki \(viewModel.items.count) öğeyi kalıcı olarak sil? Bu işlem geri alınamaz.",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Kalıcı Olarak Sil", role: .destructive) {
                viewModel.empty()
            }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HeroHeader(
                icon: "trash.slash",
                title: "Çöp Kutusu",
                subtitle: "Çöp kutusundaki öğeleri inceleyin ve kalıcı olarak silin. Silinen öğeler geri getirilemez!",
                tint: Theme.trashColor,
                actionTitle: "Tara",
                actionEnabled: !viewModel.isScanning && !viewModel.isEmptying,
                action: viewModel.scan
            )

            HStack(spacing: 12) {
                Toggle("Harici disklerin çöpünü de tara", isOn: $viewModel.includeExternal)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                if let freed = viewModel.freedBytes {
                    Label("\(formattedByteCount(freed)) boşaltıldı", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                if !viewModel.items.isEmpty {
                    Button(role: .destructive) {
                        showConfirm = true
                    } label: {
                        Label("Çöp Kutusunu Boşalt", systemImage: "trash")
                    }
                    .disabled(viewModel.isScanning || viewModel.isEmptying)
                }
            }
            .controlBar()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Çöp kutusu boş")
                .font(.title3)
            Text("Tarama tamamlandı — çöp kutunda öğe bulunamadı. Farklı bir çöp kutusu arıyorsan 'Tara' ile tekrar kontrol edebilirsin.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var results: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Toplam: \(viewModel.items.count) öğe — \(formattedByteCount(viewModel.totalSize))")
                    .font(.headline)
                Spacer()
            }

            List {
                ForEach(groupedItems, id: \.volume) { group in
                    Section {
                        ForEach(group.items) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.isDirectory ? "folder" : "doc")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(item.name)
                                    .lineLimit(1)
                                Text(item.path)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                if let date = item.date {
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 90, alignment: .trailing)
                                }
                                Text(formattedByteCount(item.size))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .contextMenu {
                                Button("Finder'da Göster") {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "externaldrive")
                                .foregroundStyle(.secondary)
                            Text(group.volume)
                                .font(.headline)
                            Text("\(group.items.count) öğe — \(formattedByteCount(group.items.reduce(0) { $0 + $1.size }))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var groupedItems: [(volume: String, items: [CleanableItem])] {
        let groups = Dictionary(grouping: viewModel.items) { item -> String in
            let path = item.path
            if path.hasPrefix("/Volumes/"), let parts = path.split(separator: "/") as [Substring]?, parts.count > 2 {
                return String(parts[2])
            }
            return "Macintosh HD (ana disk)"
        }
        return groups.map { ($0.key, $0.value) }
            .sorted { $0.items.count > $1.items.count }
    }
}