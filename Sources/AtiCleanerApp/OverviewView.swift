import SwiftUI
import AtiCleanerCore

@MainActor final class OverviewVM: ObservableObject {
    @Published var disk = DiskService.snapshot()
    @Published var memory = MemoryService.snapshot()
    @Published var quickJunk: [JunkCategory] = []
    @Published var scanning = false
    @Published var cleaning = false
    @Published var resultMessage: String?

    var junkItems: [CleanableItem] { quickJunk.flatMap(\.items).filter { !$0.isProtected } }
    var junkSize: Int64 { junkItems.reduce(0) { $0 + $1.size } }

    func quickScan() {
        guard !scanning, !cleaning else { return }
        scanning = true
        Task {
            let categories = await Task.detached { JunkScanner().scan(progress: { _ in }, isCancelled: { false }) }.value
            quickJunk = categories
            scanning = false
        }
    }

    func quickClean(permanent: Bool) {
        let paths = junkItems.map(\.path)
        guard !paths.isEmpty, !cleaning else { return }
        cleaning = true
        Task {
            let result = await Task.detached { FileUtilities.delete(paths: paths, permanent: permanent) }.value
            cleaning = false
            quickJunk = []
            disk = DiskService.snapshot()
            if result.failed.isEmpty {
                resultMessage = "\(result.succeeded) öğe \(permanent ? "kalıcı olarak silindi" : "Çöp Kutusu'na taşındı")."
            } else {
                let reasons = result.failed.prefix(3).map { "\($0.path): \($0.reason)" }.joined(separator: "\n")
                resultMessage = "\(result.succeeded) öğe silindi, \(result.failed.count) öğe silinemedi.\n\(reasons)"
            }
        }
    }
}

struct OverviewView: View {
    @StateObject private var vm = OverviewVM()
    @AppStorage("permanentDelete") private var permanentDelete = false
    @State private var confirmClean = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(icon: "gauge", title: "Ati Cleaner", subtitle: "Mac'inizi güvenli şekilde analiz edin, alan kazanın ve gereksiz dosyaları yönetin.", tint: Theme.accent)
                HStack(spacing: 24) {
                    if let disk = vm.disk {
                        ZStack {
                            Circle().stroke(Color.secondary.opacity(0.14), lineWidth: 18)
                            Circle().trim(from: 0, to: disk.usedFraction).stroke(Theme.accent, style: StrokeStyle(lineWidth: 18, lineCap: .round)).rotationEffect(.degrees(-90))
                            VStack {
                                Text("Disk").font(.headline)
                                Text(Int64(disk.available).formattedBytes).font(.title2.bold())
                                Text("boş").foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 190, height: 190)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Depolama").font(.title2.bold())
                            Text("Toplam: \(disk.total.formattedBytes)")
                            Text("Kullanılan: \(disk.used.formattedBytes)")
                            Text("Boş: \(disk.available.formattedBytes)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let memory = vm.memory {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Bellek").font(.title2.bold())
                            Text("Toplam: \(Int64(memory.total).formattedBytes)")
                            Text("Kullanılan: \(Int64(memory.used).formattedBytes)")
                            Text("Boş: \(Int64(memory.free).formattedBytes)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Theme.accent.opacity(0.12))
                            Image(systemName: "sparkles").font(.title2).foregroundStyle(Theme.accent)
                        }
                        .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hızlı Temizlik").font(.headline)
                            Text("Önbellekler, günlükler ve geçici kalıntılar tek tıkla.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if vm.scanning {
                            ProgressView("Taranıyor…")
                        } else if vm.cleaning {
                            ProgressView("Temizleniyor…")
                        } else if vm.junkSize > 0 {
                            Text("\(vm.junkItems.count) öğe • \(vm.junkSize.formattedBytes)").font(.headline)
                            Button(permanentDelete ? "Kalıcı Sil" : "Temizle", role: permanentDelete ? .destructive : nil) { confirmClean = true }
                                .buttonStyle(.borderedProminent)
                                .tint(permanentDelete ? .red : Theme.accent)
                        } else {
                            Button("Tara") { vm.quickScan() }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.accent)
                        }
                    }
                    if vm.scanning {
                        ProgressView("Sistem çöpü taranıyor…")
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
            }
        }
        .padding(24)
        .confirmationDialog(permanentDelete ? "Bulunan çöpleri kalıcı olarak silmek istediğinize emin misiniz? Bu geri alınamaz." : "Bulunan çöpleri Çöp Kutusu'na taşımak istediğinize emin misiniz?", isPresented: $confirmClean, titleVisibility: .visible) {
            Button(permanentDelete ? "Kalıcı Sil" : "Çöp Kutusu'na Taşı", role: .destructive) { vm.quickClean(permanent: permanentDelete) }
            Button("Vazgeç", role: .cancel) {}
        }
        .alert("İşlem Sonucu", isPresented: Binding(get: { vm.resultMessage != nil }, set: { on in if !on { vm.resultMessage = nil } })) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(vm.resultMessage ?? "")
        }
    }
}