import SwiftUI
import AtiCleanerCore

@MainActor final class LargeVM: ObservableObject {
    @Published var files: [LargeFileResult] = []
    @Published var scanning = false
    @Published var deleting = false
    @Published var resultMessage: String?
    @Published var minSize: Int64 = 100 * 1024 * 1024
    @Published var root = FileManager.default.homeDirectoryForCurrentUser.path

    var selected: [LargeFileResult] { files.filter(\.isSelected) }
    var selectedSize: Int64 { selected.reduce(0) { $0 + $1.size } }

    func scan() {
        guard !scanning else { return }
        scanning = true
        Task {
            let r = root; let m = minSize
            let found = await Task.detached { LargeFileScanner().scan(root: URL(fileURLWithPath: r), minSize: m, progress: { _ in }, isCancelled: { false }) }.value
            files = found
            scanning = false
        }
    }

    func setSelected(_ item: LargeFileResult, to on: Bool) {
        guard let i = files.firstIndex(where: { $0.path == item.path }) else { return }
        files[i].isSelected = on
    }

    func setAllSelected(_ on: Bool) {
        for i in files.indices { files[i].isSelected = on }
    }

    func deleteSelected(permanent: Bool) {
        let paths = selected.map(\.path)
        guard !paths.isEmpty, !deleting else { return }
        deleting = true
        Task {
            let result = await Task.detached { FileUtilities.delete(paths: paths, permanent: permanent) }.value
            deleting = false
            let removed = Set(result.deleted)
            files.removeAll { removed.contains($0.path) }
            resultMessage = Self.summary(for: result)
        }
    }

    private static func summary(for result: DeleteResult) -> String {
        if result.failed.isEmpty {
            return "\(result.succeeded) öğe silindi."
        }
        let reasons = result.failed.prefix(3).map { "\($0.path): \($0.reason)" }.joined(separator: "\n")
        return "\(result.succeeded) öğe silindi, \(result.failed.count) öğe silinemedi.\n\(reasons)"
    }
}

struct LargeFilesView: View {
    @StateObject private var vm = LargeVM()
    @AppStorage("permanentDelete") private var permanentDelete = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "doc.richtext", title: "Büyük Dosyalar", subtitle: "Boyut eşiğine ve konuma göre büyük dosyaları bulun.", tint: Theme.large, actionTitle: "Tara", action: vm.scan)
            HStack {
                Picker("Minimum Dosya Boyutu", selection: $vm.minSize) {
                    ForEach([10, 50, 100, 250, 500], id: \.self) { n in Text("\(n) MB").tag(Int64(n * 1024 * 1024)) }
                    Text("1 GB").tag(Int64(1024 * 1024 * 1024))
                    Text("2 GB").tag(Int64(2 * 1024 * 1024 * 1024))
                }
                Picker("Tarama Konumu", selection: $vm.root) {
                    Text("Ev Dizini").tag(FileManager.default.homeDirectoryForCurrentUser.path)
                    Text("Kitaplık (~/Library)").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library").path)
                    Text("Belgeler").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path)
                    Text("İndirilenler").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path)
                    Text("Masaüstü").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path)
                    Text("Filmler").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies").path)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            if vm.scanning || vm.deleting {
                ProgressView(vm.scanning ? "Dosyalar taranıyor…" : "Seçilenler siliniyor…")
            } else if vm.files.isEmpty {
                VStack(spacing: 18) {
                    ReadyRing(icon: "doc.richtext.fill", title: "Taramaya Hazır", detail: vm.minSize.formattedBytes + "+", tint: Theme.large)
                    HStack {
                        InfoTile(icon: "film.fill", title: "Videolar", subtitle: "Büyük medya dosyaları", tint: Theme.large)
                        InfoTile(icon: "archivebox.fill", title: "Arşivler", subtitle: "ZIP ve arşivler", tint: Theme.large)
                        InfoTile(icon: "externaldrive.fill", title: "Disk İmajları", subtitle: "DMG ve benzeri", tint: Theme.large)
                        InfoTile(icon: "doc.fill", title: "Belgeler", subtitle: "Büyük belgeler", tint: Theme.large)
                    }
                    .frame(maxWidth: 840)
                }
                .frame(maxWidth: .infinity)
            } else {
                DeleteBar(selectedCount: vm.selected.count, totalCount: vm.files.count, selectedSize: vm.selectedSize, permanent: permanentDelete, onToggleAll: { on in vm.setAllSelected(on) }, onDelete: { confirmDelete = true })
                List(vm.files) { f in
                    HStack {
                        Toggle("", isOn: Binding(get: { f.isSelected }, set: { vm.setSelected(f, to: $0) }))
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.name).font(.body)
                            Text(f.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Text(f.size.formattedBytes).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .revealInFinder(f.path)
                }
            }
        }
        .padding(24)
        .confirmationDialog(permanentDelete ? "Seçilen dosyaları kalıcı olarak silmek istediğinize emin misiniz? Bu geri alınamaz." : "Seçilen dosyaları Çöp Kutusu'na taşımak istediğinize emin misiniz?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(permanentDelete ? "Kalıcı Sil" : "Çöp Kutusu'na Taşı", role: .destructive) { vm.deleteSelected(permanent: permanentDelete) }
            Button("Vazgeç", role: .cancel) {}
        }
        .alert("İşlem Sonucu", isPresented: Binding(get: { vm.resultMessage != nil }, set: { if !$0 { vm.resultMessage = nil } })) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(vm.resultMessage ?? "")
        }
    }
}