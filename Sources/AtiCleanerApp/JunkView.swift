import SwiftUI
import AtiCleanerCore

@MainActor final class JunkVM: ObservableObject {
    @Published var categories: [JunkCategory] = []
    @Published var scanning = false
    @Published var deleting = false
    @Published var resultMessage: String?
    @Published var warnings: [String] = []
    @Published var progress = ScanProgress(phase: "Hazır")

    var allItems: [CleanableItem] { categories.flatMap(\.items) }
    var deletableItems: [CleanableItem] { allItems.filter { !$0.isProtected } }
    var selected: [CleanableItem] { deletableItems.filter(\.isSelected) }
    var selectedSize: Int64 { selected.reduce(0) { $0 + $1.size } }
    var total: Int64 { deletableItems.reduce(0) { $0 + $1.size } }

    func scan() {
        guard !scanning else { return }
        scanning = true
        warnings = []
        Task {
            let found = await Task.detached { JunkScanner().scan(progress: { p in Task { @MainActor in self.progress = p } }, isCancelled: { false }, onError: { w in Task { @MainActor in self.warnings.append(w) } }) }.value
            categories = found
            scanning = false
        }
    }

    func setSelected(_ item: CleanableItem, to on: Bool) {
        guard let ci = categories.firstIndex(where: { $0.items.contains { $0.path == item.path } }),
              let ii = categories[ci].items.firstIndex(where: { $0.path == item.path }) else { return }
        categories[ci].items[ii].isSelected = on
    }

    func setAllSelected(_ on: Bool) {
        for i in categories.indices {
            for j in categories[i].items.indices where !categories[i].items[j].isProtected {
                categories[i].items[j].isSelected = on
            }
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
            for i in categories.indices {
                categories[i].items.removeAll { removed.contains($0.path) }
            }
            categories.removeAll { $0.items.isEmpty }
            resultMessage = Self.summary(for: result)
        }
    }

    private static func summary(for result: DeleteResult) -> String {
        "\(result.succeeded) öğe silindi."
    }
}

@MainActor struct JunkView: View {
    @StateObject private var vm = JunkVM()
    @AppStorage("permanentDelete") private var permanentDelete = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(icon: "paintbrush.fill", title: "Sistem Çöpü", subtitle: "Bilinen kullanıcı önbellekleri, günlükler ve geçici kalıntıları tarayın.", tint: Theme.junk, actionTitle: "Tara", action: vm.scan)
            if vm.scanning || vm.deleting {
                ProgressView(vm.scanning ? vm.progress.phase : "Seçilenler siliniyor…")
            } else if vm.categories.isEmpty {
                VStack(spacing: 18) {
                    ReadyRing(icon: "paintbrush.fill", title: "Taramaya Hazır", detail: "Güvenli kullanıcı alanları", tint: Theme.junk)
                    HStack {
                        InfoTile(icon: "shippingbox", title: "Önbellekler", subtitle: "Uygulamaların yeniden oluşturabildiği veriler", tint: Theme.junk)
                        InfoTile(icon: "doc.text", title: "Günlükler", subtitle: "Eski uygulama günlükleri", tint: Theme.junk)
                        InfoTile(icon: "shield.checkered", title: "Güvenli Politika", subtitle: "Sistem kökleri dışarıda bırakılır", tint: Theme.junk)
                    }
                    .frame(maxWidth: 820)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("Bulunan toplam: \(vm.total.formattedBytes)").font(.title2.bold())
                DeleteBar(selectedCount: vm.selected.count, totalCount: vm.deletableItems.count, selectedSize: vm.selectedSize, permanent: permanentDelete, onToggleAll: { on in MainActor.assumeIsolated { vm.setAllSelected(on) } }, onDelete: { confirmDelete = true })
                List(vm.categories) { cat in
                    Section("\(cat.name) — \(cat.deletableSize.formattedBytes)") {
                        ForEach(cat.items.filter { !$0.isProtected }) { item in
                            HStack {
                                Toggle("", isOn: Binding(get: { item.isSelected }, set: { vm.setSelected(item, to: $0) }))
                                    .labelsHidden()
                                    .toggleStyle(.checkbox)
                                    .disabled(item.isProtected)
                                Image(systemName: item.isProtected ? "lock" : (item.isDirectory ? "folder" : "doc"))
                                    .foregroundStyle(item.isProtected ? .secondary : .primary)
                                Text(item.name).foregroundStyle(item.isProtected ? .secondary : .primary)
                                if item.isProtected {
                                    Text("Sistem korumalı").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.size.formattedBytes).foregroundStyle(.secondary)
                            }
                            .revealInFinder(item.path)
                        }
                    }
                }
            }
        }
        .padding(24)
        .confirmationDialog(permanentDelete ? "Seçilenleri kalıcı olarak silmek istediğinize emin misiniz? Bu geri alınamaz." : "Seçilenleri Çöp Kutusu'na taşımak istediğinize emin misiniz?", isPresented: $confirmDelete, titleVisibility: .visible) {
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