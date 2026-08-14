import SwiftUI
import AtiCleanerCore

@MainActor final class SystemDataVM: ObservableObject {
    @Published var items: [SystemDataItem] = []
    @Published var scanning = false
    @Published var deleting = false
    @Published var resultMessage: String?
    @Published var helperInstalled = PrivilegedHelper.isInstalled()

    var selected: [SystemDataItem] { items.filter(\.isSelected) }
    var selectedSize: Int64 { selected.reduce(0) { $0 + $1.size } }

    func scan() {
        guard !scanning else { return }
        scanning = true
        helperInstalled = PrivilegedHelper.isInstalled()
        Task {
            let found = await Task.detached { SystemDataScanner().scan() }.value
            items = found
            scanning = false
        }
    }

    func setSelected(_ item: SystemDataItem, to on: Bool) {
        guard let i = items.firstIndex(where: { $0.path == item.path }) else { return }
        items[i].isSelected = on
    }

    func setAllSelected(_ on: Bool) {
        for i in items.indices where !items[i].isProtected { items[i].isSelected = on }
    }

    func deleteSelected() {
        let paths = selected.map(\.path)
        guard !paths.isEmpty, !deleting else { return }
        deleting = true
        Task {
            if PrivilegedHelper.isInstalled() {
                let ok = await Task.detached { PrivilegedHelper.deleteSystemPaths(paths) }.value
                deleting = false
                if ok {
                    items.removeAll { paths.contains($0.path) }
                    resultMessage = "\(paths.count) öğe sistemden kalıcı olarak silindi."
                } else {
                    resultMessage = "Silme işlemi başarısız oldu."
                }
            } else {
                let ok = await Task.detached { PrivilegedHelper.install(sourceBinary: Bundle.main.executablePath ?? "") }.value
                helperInstalled = ok
                deleting = false
                if ok {
                    resultMessage = "Yardımcı kuruldu. Silme işlemini tekrar deneyin."
                } else {
                    resultMessage = "Yardımcı kurulamadı (izin alınamadı)."
                }
            }
        }
    }
}

struct SystemDataView: View {
    @StateObject private var vm = SystemDataVM()
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(icon: "internaldrive.fill", title: "Sistem Verisi", subtitle: "Uygulama destek dosyalarını (Adobe vb.) sistem düzeyinde inceleyin.", tint: Theme.system, actionTitle: "Tara", action: vm.scan)
            HStack(spacing: 8) {
                Image(systemName: vm.helperInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(vm.helperInstalled ? .green : .orange)
                Text(vm.helperInstalled ? "Sistem silme yardımcısı kurulu" : "Silme için tek seferlik yönetici izni istenir")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            if vm.scanning || vm.deleting {
                ProgressView(vm.scanning ? "Uygulama destek dosyaları taranıyor…" : "Siliniyor…")
            } else if vm.items.isEmpty {
                VStack(spacing: 18) {
                    ReadyRing(icon: "internaldrive.fill", title: "Taramaya Hazır", detail: "/Library/Application Support", tint: Theme.system)
                    HStack {
                        InfoTile(icon: "externaldrive.fill", title: "Sistem Düzeyi", subtitle: "Tüm kullanıcıların paylaştığı uygulama verileri", tint: Theme.system)
                        InfoTile(icon: "exclamationmark.triangle.fill", title: "Kalıcı Silme", subtitle: "Sistemden kaldırılır, Çöp Kutusu'na gitmez", tint: Theme.system)
                        InfoTile(icon: "square.and.pencil", title: "El İle Seçim", subtitle: "Yalnız sizin seçtikleriniz silinir", tint: Theme.system)
                    }
                    .frame(maxWidth: 820)
                }
                .frame(maxWidth: .infinity)
            } else {
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
                        Label("Kalıcı Sil", systemImage: "trash.slash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(vm.selected.count == 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                List(vm.items) { item in
                    HStack {
                        Toggle("", isOn: Binding(get: { item.isSelected }, set: { vm.setSelected(item, to: $0) }))
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                            .disabled(item.isProtected)
                        Image(systemName: item.isProtected ? "lock" : "folder")
                        Text(item.name)
                        Text(item.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(item.size.formattedBytes).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .confirmationDialog("Seçilen uygulama destek dosyaları /Library/Application Support içinden KALICI olarak silinecek. Çöp Kutusu'na gitmez ve geri alınamaz. Emin misiniz?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Kalıcı Sil", role: .destructive) { vm.deleteSelected() }
            Button("Vazgeç", role: .cancel) {}
        }
        .alert("İşlem Sonucu", isPresented: Binding(get: { vm.resultMessage != nil }, set: { if !$0 { vm.resultMessage = nil } })) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(vm.resultMessage ?? "")
        }
    }
}