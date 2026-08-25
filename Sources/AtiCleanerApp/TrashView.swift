import SwiftUI
import AtiCleanerCore

@MainActor final class TrashVM: ObservableObject {
    @Published var items: [CleanableItem] = []
    @Published var includeExternal = false
    @Published var scanning = false
    @Published var deleting = false
    @Published var resultMessage: String?

    var selected: [CleanableItem] { items.filter(\.isSelected) }
    var selectedSize: Int64 { selected.reduce(0) { $0 + $1.size } }
    var total: Int64 { items.reduce(0) { $0 + $1.size } }

    func scan() {
        guard !scanning else { return }
        scanning = true
        Task {
            let ext = includeExternal
            let found = await Task.detached { TrashScanner.items(includeExternal: ext) }.value
            items = found
            scanning = false
        }
    }

    func setSelected(_ item: CleanableItem, to on: Bool) {
        guard let i = items.firstIndex(where: { $0.path == item.path }) else { return }
        items[i].isSelected = on
    }

    func setAllSelected(_ on: Bool) {
        for i in items.indices { items[i].isSelected = on }
    }

    func deleteSelected() {
        let paths = selected.map(\.path)
        guard !paths.isEmpty, !deleting else { return }
        deleting = true
        Task {
            let result = await Task.detached { FileUtilities.permanentDelete(paths: paths) }.value
            deleting = false
            let removed = Set(result.deleted)
            items.removeAll { removed.contains($0.path) }
            resultMessage = Self.summary(for: result)
        }
    }

    private static func summary(for result: DeleteResult) -> String {
        if result.failed.isEmpty {
            return "\(result.succeeded) öğe çöp kutusundan kalıcı olarak silindi."
        }
        let reasons = result.failed.prefix(3).map { "\($0.path): \($0.reason)" }.joined(separator: "\n")
        return "\(result.succeeded) öğe silindi, \(result.failed.count) öğe silinemedi.\n\(reasons)"
    }
}

@MainActor struct TrashView: View {
    @StateObject private var vm = TrashVM()
    @State private var confirmDelete = false

    private var bootVolumeName: String {
        (try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? "Macintosh HD"
    }

    private var externalVolumes: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: "/Volumes")) ?? [])
            .filter { !$0.hasPrefix(".") && $0 != bootVolumeName }
    }

    private var excludedVolumes: [String] { SafetyPolicy.excludedVolumeNames }

    private func setExcluded(_ name: String, _ on: Bool) {
        var names = SafetyPolicy.excludedVolumeNames
        if on { if !names.contains(name) { names.append(name) } }
        else { names.removeAll { $0 == name } }
        SafetyPolicy.setExcludedVolumeNames(names)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(icon: "trash", title: "Çöp Kutusu", subtitle: "Mac ve isteğe bağlı harici disk çöp kutularını inceleyin.", tint: Theme.trash, actionTitle: "Tara", action: vm.scan)
            Toggle("Harici disklerin çöp kutularını da tara", isOn: $vm.includeExternal)
                .toggleStyle(.switch)
            if !externalVolumes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hariç Tutulan Diskler").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ForEach(externalVolumes, id: \.self) { name in
                            Toggle(name, isOn: Binding(get: { excludedVolumes.contains(name) }, set: { on in setExcluded(name, on) }))
                                .toggleStyle(.switch)
                                .font(.caption)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            }
            if vm.scanning || vm.deleting {
                ProgressView(vm.scanning ? "Çöp kutusu taranıyor…" : "Seçilenler siliniyor…")
            } else if vm.items.isEmpty {
                VStack(spacing: 18) {
                    ReadyRing(icon: "trash", title: "Taramaya Hazır", detail: vm.includeExternal ? "Mac + harici diskler" : "Yalnız Mac", tint: Theme.trash)
                    HStack {
                        InfoTile(icon: "internaldrive.fill", title: "Mac Çöp Kutusu", subtitle: "Kullanıcı çöp kutusu", tint: Theme.trash)
                        InfoTile(icon: "externaldrive.fill", title: "Harici Diskler", subtitle: vm.includeExternal ? "Taramaya dahil" : "İsteğe bağlı", tint: Theme.trash)
                        InfoTile(icon: "eye.fill", title: "Önce İncele", subtitle: "Silmeden önce listeyi kontrol edin", tint: Theme.trash)
                    }
                    .frame(maxWidth: 820)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("Bulunan toplam: \(vm.total.formattedBytes)").font(.title2.bold())
                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(get: { vm.items.count > 0 && vm.selected.count == vm.items.count }, set: { on in vm.setAllSelected(on) }))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                    Text("\(vm.selected.count)/\(vm.items.count) öğe seçildi")
                        .font(.headline)
                    Text("• \(vm.selectedSize.formattedBytes)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive, action: { confirmDelete = true }) {
                        Label("Çöp Kutusunu Boşalt", systemImage: "trash.slash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(vm.selected.count == 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                List(vm.items) { i in
                    HStack {
                        Toggle("", isOn: Binding(get: { i.isSelected }, set: { on in vm.setSelected(i, to: on) }))
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        Image(systemName: i.isDirectory ? "folder" : "doc")
                        Text(i.name)
                        Spacer()
                        Text(i.size.formattedBytes).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .revealInFinder(i.path)
                }
            }
        }
        .padding(24)
        .confirmationDialog("Seçilen öğeler çöp kutusundan kalıcı olarak silinecek. Bu geri alınamaz. Emin misiniz?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Kalıcı Sil", role: .destructive) { vm.deleteSelected() }
            Button("Vazgeç", role: .cancel) {}
        }
        .alert("İşlem Sonucu", isPresented: Binding(get: { vm.resultMessage != nil }, set: { on in if !on { vm.resultMessage = nil } })) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(vm.resultMessage ?? "")
        }
    }
}