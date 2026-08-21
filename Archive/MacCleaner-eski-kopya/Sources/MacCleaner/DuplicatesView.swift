import SwiftUI
import MacCleanerCore

@MainActor
final class DuplicatesViewModel: ObservableObject {
    @Published var groups: [DuplicateGroup] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var progress = ScanProgress(phase: "Hazır", processed: 0, total: -1)
    @Published var freedBytes: Int64?
    @Published var errorMessage: String?
    @Published var minSize: Int64 = 5 * 1024 * 1024
    @Published var rootPath = FileManager.default.homeDirectoryForCurrentUser.path

    private var token = CancellationToken()

    var selectedSize: Int64 { groups.reduce(0) { $0 + $1.selectedSize } }
    var selectedCount: Int { groups.reduce(0) { $0 + $1.selectedCount } }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        isCleaning = false
        freedBytes = nil
        errorMessage = nil
        token = CancellationToken()
        let token = self.token
        let rootPath = self.rootPath
        let minSize = self.minSize

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let found = DuplicateScanner().scan(
                root: URL(fileURLWithPath: rootPath),
                minSize: minSize
            ) { p in
                DispatchQueue.main.async {
                    self.progress = p
                }
            } isCancelled: {
                token.isCancelled
            }

            DispatchQueue.main.async {
                self.groups = found
                self.isScanning = false
                self.progress = ScanProgress(
                    phase: "\(found.count) çift dosya grubu bulundu",
                    processed: Int64(found.count),
                    total: -1,
                    detail: nil
                )
            }
        }
    }

    func cancel() {
        token.cancel()
    }

    func clean() {
        guard !isCleaning, selectedCount > 0 else { return }
        isCleaning = true
        errorMessage = nil
        token = CancellationToken()
        let token = self.token
        let permanent = UserDefaults.standard.bool(forKey: "permanentDelete")
        let paths = groups.flatMap { $0.files }.filter(\.isSelected).map(\.path)
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
                if result.succeeded > 0 {
                    let deleted = Set(paths)
                    for index in self.groups.indices {
                        self.groups[index].files.removeAll { deleted.contains($0.path) }
                    }
                    self.groups.removeAll { $0.files.count < 2 }
                }
            }
        }
    }
}

struct DuplicatesView: View {
    @StateObject private var viewModel = DuplicatesViewModel()
    @State private var showConfirmDelete = false
    @AppStorage("permanentDelete") private var permanentDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if viewModel.isScanning {
                ScanningPanel(progress: viewModel.progress, onCancel: viewModel.cancel)
            } else if viewModel.isCleaning {
                ScanningPanel(progress: viewModel.progress, onCancel: viewModel.cancel)
            } else if viewModel.groups.isEmpty {
                emptyState
            } else {
                results
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            permanentDelete
                ? "Seçili \(viewModel.selectedCount) dosya KALICI olarak silinecek — geri alınamaz!"
                : "",
            isPresented: $showConfirmDelete,
            titleVisibility: .visible
        ) {
            if permanentDelete {
                Button("Kalıcı Olarak Sil", role: .destructive) {
                    viewModel.clean()
                }
                Button("Vazgeç", role: .cancel) {}
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeroHeader(
                icon: "doc.on.doc",
                title: "Çift Dosyalar",
                subtitle: "Aynı içeriğe sahip dosyaları bulun. Dosya adları farklı olsa bile içerikleri SHA-256 ile karşılaştırılır.",
                tint: Theme.duplicateColor,
                actionTitle: "Tara",
                actionEnabled: !viewModel.isScanning && !viewModel.isCleaning,
                action: viewModel.scan
            )

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Minimum Dosya Boyutu", systemImage: "arrow.up.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Picker("", selection: $viewModel.minSize) {
                        Text("5 MB").tag(Int64(5 * 1024 * 1024))
                        Text("10 MB").tag(Int64(10 * 1024 * 1024))
                        Text("50 MB").tag(Int64(50 * 1024 * 1024))
                        Text("100 MB").tag(Int64(100 * 1024 * 1024))
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                VStack(alignment: .leading, spacing: 6) {
                    Label("Tarama Konumu", systemImage: "folder.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Picker("", selection: $viewModel.rootPath) {
                        Text("Ev Dizini").tag(FileManager.default.homeDirectoryForCurrentUser.path)
                        Text("Belgeler").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path)
                        Text("İndirilenler").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path)
                        Text("Masaüstü").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path)
                        Text("Fotoğraflar").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures").path)
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                if let freed = viewModel.freedBytes {
                    Label("\(formattedByteCount(freed)) boşaltıldı", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 16)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(
                        Theme.duplicateColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 160, height: 160)

                VStack(spacing: 5) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(Theme.duplicateColor)

                    Text("Taramaya Hazır")
                        .font(.headline)

                    Text(formattedByteCount(viewModel.minSize) + "+")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 6) {
                Text("Gerçek çift dosyaları bulun")
                    .font(.title2.bold())

                Text("Dosya adları farklı olsa bile içerikleri karşılaştırılır. Aynı içeriğe sahip kopyalar gruplandırılır.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 650)
            }

            HStack(spacing: 12) {
                DuplicateTypeCard(
                    icon: "photo.fill",
                    title: "Fotoğraflar",
                    subtitle: "Aynı görsel dosyaları"
                )

                DuplicateTypeCard(
                    icon: "film.fill",
                    title: "Videolar",
                    subtitle: "Tekrarlanan videolar"
                )

                DuplicateTypeCard(
                    icon: "doc.text.fill",
                    title: "Belgeler",
                    subtitle: "Aynı belge kopyaları"
                )

                DuplicateTypeCard(
                    icon: "folder.fill",
                    title: "Diğer Dosyalar",
                    subtitle: "Aynı içeriğe sahip dosyalar"
                )
            }
            .frame(maxWidth: 820)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Theme.duplicateColor)

                Text("İçerik doğrulama:")
                    .foregroundStyle(.secondary)

                Text("SHA-256")
                    .fontWeight(.semibold)

                Text("•")
                    .foregroundStyle(.tertiary)

                Text("İlk kopya korunur")
                    .fontWeight(.semibold)

                Text("•")
                    .foregroundStyle(.tertiary)

                Text("En az \(formattedByteCount(viewModel.minSize))")
                    .fontWeight(.semibold)
            }
            .font(.caption)

            Button {
                viewModel.scan()
            } label: {
                Label("Çift Dosyaları Tara", systemImage: "doc.on.doc")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.duplicateColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
    }

    private var results: some View {
        VStack(spacing: 10) {
            HStack {
                if viewModel.selectedCount > 0 {
                    Text("Seçili: \(viewModel.selectedCount) dosya — \(formattedByteCount(viewModel.selectedSize))")
                        .font(.headline)
                    Spacer()
                    Button("Çöp Kutusuna Taşı (\(viewModel.selectedCount))") {
                        if permanentDelete {
                            showConfirmDelete = true
                        } else {
                            viewModel.clean()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Hiçbir dosya seçilmedi")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            List {
                ForEach($viewModel.groups) { $group in
                    DuplicateGroupSection(group: $group)
                }
            }
            .listStyle(.inset)
        }
    }
}

struct DuplicateGroupSection: View {
    @Binding var group: DuplicateGroup

    var body: some View {
        DisclosureGroup(isExpanded: $group.isExpanded) {
            ForEach($group.files) { $file in
                HStack(spacing: 10) {
                    Image(systemName: "doc")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Toggle(URL(fileURLWithPath: file.path).lastPathComponent, isOn: $file.isSelected)
                        .toggleStyle(.checkbox)
                        .lineLimit(1)
                    Text(file.path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if let date = file.date {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 90, alignment: .trailing)
                    }
                }
                .contextMenu {
                    Button("Finder'da Göster") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
                    }
                    Button("Dosyayı Aç") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                Text("\(group.files.count) kopya")
                    .font(.headline)
                Text("İsraf: \(formattedByteCount(group.wasteSize))")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Text(formattedByteCount(group.fileSize))
                    .font(.headline.monospacedDigit())
            }
        }
    }
}
struct DuplicateTypeCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.duplicateColor.opacity(0.12))

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.duplicateColor)
            }
            .frame(width: 46, height: 46)

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
