import SwiftUI
import MacCleanerCore

@MainActor
final class UninstallerViewModel: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var isScanning = false
    @Published var isUninstalling = false
    @Published var progress = ScanProgress(phase: "Hazır", processed: 0, total: -1)
    @Published var freedBytes: Int64?
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var permanentlyDelete = UserDefaults.standard.bool(forKey: "permanentDelete")

    private var token = CancellationToken()

    var filteredApps: [AppInfo] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedApps: [AppInfo] { apps.filter(\.isSelected) }
    var selectedSize: Int64 { selectedApps.reduce(0) { $0 + $1.totalSize } }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        isUninstalling = false
        freedBytes = nil
        errorMessage = nil
        token = CancellationToken()
        let token = self.token

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let found = AppScanner().scanApps { p in
                DispatchQueue.main.async {
                    self.progress = p
                }
            } isCancelled: {
                token.isCancelled
            }

            DispatchQueue.main.async {
                self.apps = found
                self.isScanning = false
                self.progress = ScanProgress(
                    phase: "\(found.count) uygulama bulundu",
                    processed: Int64(found.count),
                    total: Int64(found.count),
                    detail: nil
                )
            }
        }
    }

    func cancel() {
        token.cancel()
    }

    func uninstall() {
        guard !isUninstalling else { return }
        let targets = selectedApps.filter { !$0.isSystem }
        guard !targets.isEmpty else { return }
        isUninstalling = true
        errorMessage = nil
        token = CancellationToken()
        let token = self.token

        var paths: [String] = []
        for app in targets {
            paths.append(app.path)
            paths.append(contentsOf: app.leftovers.filter(\.isSelected).map(\.path))
        }
        let total = paths.count
        let targetPaths = Set(targets.map(\.path))
        let permanently = self.permanentlyDelete

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = permanently
                ? FileUtils.permanentlyDeleteItems(paths: paths) { done, _, freed in
                    DispatchQueue.main.async {
                        self.progress = ScanProgress(
                            phase: "Kaldırılıyor… \(done)/\(total)",
                            processed: Int64(done),
                            total: Int64(total),
                            detail: nil
                        )
                        self.freedBytes = freed
                    }
                } isCancelled: {
                    token.isCancelled
                }
                : FileUtils.trashItems(paths: paths) { done, _, freed in
                    DispatchQueue.main.async {
                        self.progress = ScanProgress(
                            phase: "Kaldırılıyor… \(done)/\(total)",
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
                self.isUninstalling = false
                self.freedBytes = result.freedBytes
                if result.failed > 0 {
                    self.errorMessage = "\(result.failed) öğe silinemedi: \(result.errors.prefix(3).joined(separator: " • "))"
                }
                self.apps.removeAll { targetPaths.contains($0.path) }
            }
        }
    }
}

struct UninstallerView: View {
    @StateObject private var viewModel = UninstallerViewModel()
    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if viewModel.isScanning {
                ScanningPanel(progress: viewModel.progress, onCancel: viewModel.cancel)
            } else if viewModel.isUninstalling {
                ScanningPanel(progress: viewModel.progress, onCancel: viewModel.cancel)
            } else if viewModel.apps.isEmpty {
                emptyState
            } else {
                results
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            viewModel.permanentlyDelete
                ? "\(viewModel.selectedApps.count) uygulamayı artık dosyalarıyla birlikte KALICI OLARAK sil? Bu işlem geri alınamaz!"
                : "\(viewModel.selectedApps.count) uygulamayı artık dosyalarıyla birlikte çöp kutusuna taşı?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button(viewModel.permanentlyDelete ? "Kalıcı Olarak Sil" : "Çöp Kutusuna Taşı", role: .destructive) {
                viewModel.uninstall()
            }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HeroHeader(
                icon: "xmark.app",
                title: "Uygulama Kaldırıcı",
                subtitle: "Uygulamaları tercihler, önbellekler ve destek dosyalarıyla birlikte tamamen kaldırın. Kaldırılan her şey çöp kutusuna taşınır.",
                tint: Theme.uninstallColor,
                actionTitle: "Tara",
                actionEnabled: !viewModel.isScanning && !viewModel.isUninstalling,
                action: viewModel.scan
            )

            HStack(spacing: 12) {
                TextField("Ara…", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                Toggle("Kalıcı olarak sil (geri alınamaz)", isOn: $viewModel.permanentlyDelete)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Spacer()

                if let freed = viewModel.freedBytes {
                    Label("\(formattedByteCount(freed)) boşaltıldı", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if viewModel.selectedSize > 0 {
                    Button("Seçilileri Kaldır (\(viewModel.selectedApps.count))") {
                        showConfirm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedApps.allSatisfy(\.isSystem))
                }
            }
            .controlBar()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.app")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Henüz tarama yapılmadı")
                .font(.title3)
            Text("Uygulamaları listelemek için 'Tara' düğmesine basın.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var results: some View {
        List {
            ForEach(viewModel.filteredApps) { app in
                if let index = viewModel.apps.firstIndex(where: { $0.id == app.id }) {
                    AppRow(app: $viewModel.apps[index])
                }
            }
        }
        .listStyle(.inset)
    }
}

struct AppRow: View {
    @Binding var app: AppInfo

    var body: some View {
        DisclosureGroup(isExpanded: $app.isExpanded) {
            if app.leftovers.isEmpty {
                Text("Artık dosya bulunamadı")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Artık dosyalar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedByteCount(app.leftovers.reduce(0) { $0 + $1.size }))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach($app.leftovers) { $leftover in
                        HStack(spacing: 8) {
                            Image(systemName: leftover.isDirectory ? "folder" : "doc")
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Toggle("\(leftover.name) — \(leftover.path)", isOn: $leftover.isSelected)
                                .toggleStyle(.checkbox)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(formattedByteCount(leftover.size))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 28)
            }
        } label: {
            HStack(spacing: 10) {
                AppIconView(path: app.path)
                    .frame(width: 28, height: 28)

                if app.isSystem {
                    Text(app.name)
                        .font(.headline)
                    Text("Sistem uygulaması")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Toggle(app.name, isOn: $app.isSelected)
                        .toggleStyle(.checkbox)
                        .font(.headline)
                        .lineLimit(1)
                }

                if let version = app.version {
                    Text("v\(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(app.bundleID)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if !app.leftovers.isEmpty {
                    Text("+\(formattedByteCount(app.leftovers.reduce(0) { $0 + $1.size })) artık")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(formattedByteCount(app.size))
                    .font(.headline.monospacedDigit())
            }
        }
    }
}

struct AppIconView: View {
    let path: String

    var body: some View {
        Group {
            if FileManager.default.fileExists(atPath: path) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
            } else {
                Image(systemName: "app")
            }
        }
    }
}