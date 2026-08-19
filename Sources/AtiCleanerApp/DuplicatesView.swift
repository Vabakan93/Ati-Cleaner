import SwiftUI
import AtiCleanerCore

@MainActor final class DupVM: ObservableObject {
    @Published var groups: [DuplicateGroup] = []
    @Published var scanning = false
    @Published var deleting = false
    @Published var resultMessage: String?
    @Published var minSize: Int64 = 5 * 1024 * 1024
    @Published var root = FileManager.default.homeDirectoryForCurrentUser.path

    var allFiles: [DuplicateFile] { groups.flatMap(\.files) }
    var selected: [DuplicateFile] { allFiles.filter(\.isSelected) }
    var selectedSize: Int64 { selected.reduce(0) { $0 + $1.size } }

    func scan() {
        guard !scanning else { return }
        scanning = true
        Task {
            let r = root; let m = minSize
            let found = await Task.detached { DuplicateScanner().scan(root: URL(fileURLWithPath: r), minSize: m, progress: { _ in }, isCancelled: { false }) }.value
            groups = found
            scanning = false
        }
    }

    func setSelected(_ file: DuplicateFile, to on: Bool) {
        guard let gi = groups.firstIndex(where: { $0.files.contains { $0.path == file.path } }),
              let fi = groups[gi].files.firstIndex(where: { $0.path == file.path }) else { return }
        groups[gi].files[fi].isSelected = on
    }

    func setAllSelected(_ on: Bool) {
        for gi in groups.indices {
            for fi in groups[gi].files.indices { groups[gi].files[fi].isSelected = on }
        }
    }

    func deleteSelected(permanent: Bool) {
        let paths = selected.map(\.path)
        guard !paths.isEmpty, !deleting else { return }
        deleting = true
        Task {
            let result = await Task.detached { FileUtilities.delete(paths: paths, permanent: permanent) }.value
            deleting = false
            let removed = Set(result.deleted)
            for gi in groups.indices {
                groups[gi].files.removeAll { removed.contains($0.path) }
            }
            groups.removeAll { $0.files.count < 2 }
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

@MainActor struct DuplicatesView: View {
    @StateObject private var vm = DupVM()
    @AppStorage("permanentDelete") private var permanentDelete = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "doc.on.doc", title: "Çift Dosyalar", subtitle: "Dosya adı farklı olsa bile aynı içeriği SHA-256 ile doğrulayın.", tint: Theme.duplicates, actionTitle: "Tara", action: vm.scan)
            HStack {
                Picker("Minimum Dosya Boyutu", selection: $vm.minSize) {
                    ForEach([1, 5, 10, 50, 100], id: \.self) { n in Text("\(n) MB").tag(Int64(n * 1024 * 1024)) }
                }
                Picker("Tarama Konumu", selection: $vm.root) {
                    Text("Ev Dizini").tag(FileManager.default.homeDirectoryForCurrentUser.path)
                    Text("Belgeler").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path)
                    Text("İndirilenler").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path)
                    Text("Masaüstü").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path)
                    Text("Fotoğraflar").tag(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures").path)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            if vm.scanning || vm.deleting {
                ProgressView(vm.scanning ? "Dosya içerikleri karşılaştırılıyor…" : "Seçilenler siliniyor…")
            } else if vm.groups.isEmpty {
                VStack(spacing: 18) {
                    ReadyRing(icon: "doc.on.doc.fill", title: "Taramaya Hazır", detail: vm.minSize.formattedBytes + "+", tint: Theme.duplicates)
                    HStack {
                        InfoTile(icon: "photo.fill", title: "Fotoğraflar", subtitle: "Aynı görseller", tint: Theme.duplicates)
                        InfoTile(icon: "film.fill", title: "Videolar", subtitle: "Aynı videolar", tint: Theme.duplicates)
                        InfoTile(icon: "doc.text.fill", title: "Belgeler", subtitle: "Aynı belgeler", tint: Theme.duplicates)
                        InfoTile(icon: "checkmark.shield.fill", title: "SHA-256", subtitle: "İçerik doğrulama", tint: Theme.duplicates)
                    }
                    .frame(maxWidth: 840)
                }
                .frame(maxWidth: .infinity)
            } else {
                DeleteBar(selectedCount: vm.selected.count, totalCount: vm.allFiles.count, selectedSize: vm.selectedSize, permanent: permanentDelete, onToggleAll: { on in MainActor.assumeIsolated { vm.setAllSelected(on) } }, onDelete: { confirmDelete = true })
                List(vm.groups) { g in
                    Section("\(g.files.count) kopya • İsraf \(g.wasteSize.formattedBytes)") {
                        ForEach(g.files) { f in
                            HStack {
                                Toggle("", isOn: Binding(get: { f.isSelected }, set: { vm.setSelected(f, to: $0) }))
                                    .labelsHidden()
                                    .toggleStyle(.checkbox)
                                Text(URL(fileURLWithPath: f.path).lastPathComponent)
                                Text(f.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Text(f.size.formattedBytes).monospacedDigit().foregroundStyle(.secondary)
                            }
                            .revealInFinder(f.path)
                        }
                    }
                }
            }
        }
        .padding(24)
        .confirmationDialog(permanentDelete ? "Seçilen kopyaları kalıcı olarak silmek istediğinize emin misiniz? Bu geri alınamaz." : "Seçilen kopyaları Çöp Kutusu'na taşımak istediğinize emin misiniz?", isPresented: $confirmDelete, titleVisibility: .visible) {
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