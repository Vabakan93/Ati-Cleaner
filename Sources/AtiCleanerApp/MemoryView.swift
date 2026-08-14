import SwiftUI
import AtiCleanerCore

struct MemoryView: View {
    @State private var snap = MemoryService.snapshot()
    @State private var relieving = false
    @State private var lastRelief: String?
    @State private var helperInstalled = PrivilegedHelper.isInstalled()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(icon: "memorychip", title: "Bellek", subtitle: "Anlık bellek kullanımını görüntüleyin ve bellek basıncını rahatlatın.", tint: Theme.memory, actionTitle: "Rahatlat", action: relieve)
            HStack(spacing: 8) {
                Image(systemName: helperInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(helperInstalled ? .green : .orange)
                Text(helperInstalled ? "Önbellek yardımcısı kurulu — şifre sormadan çalışır" : "İlk rahatlatmada tek seferlik yönetici izni istenir")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if helperInstalled {
                    Button("Yardımcıyı Kaldır") { uninstallHelper() }
                        .font(.caption)
                }
            }
            if let s = snap {
                HStack(spacing: 32) {
                    ReadyRing(icon: "memorychip.fill", title: "Bellek", detail: "\(Int(s.used * 100 / max(s.total, 1)))% kullanım", tint: Theme.memory)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Toplam: \(Int64(s.total).formattedBytes)").font(.title3)
                        Text("Kullanılan: \(Int64(s.used).formattedBytes)").font(.title3)
                        Text("Boş: \(Int64(s.free).formattedBytes)").font(.title3)
                        Text("Dosya Önbelleği: \(Int64(s.cache).formattedBytes)").font(.title3).foregroundStyle(.secondary)
                        Text("Sıkıştırılmış: \(Int64(s.compressed).formattedBytes)").font(.title3)
                        Text("macOS boş belleği dosya önbelleği için kullanır; düşük \"Boş\" değeri normaldir, önbellek gerektiğinde anında boşaltılır.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if relieving {
                            ProgressView("Bellek rahatlatılıyor… (yönetici izni istenebilir)")
                        }
                        if let lastRelief {
                            Text(lastRelief)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Bellek bilgisi okunamadı")
            }
            Spacer()
        }
        .padding(24)
        .task { snap = MemoryService.snapshot() }
    }

    private func relieve() {
        guard !relieving else { return }
        relieving = true
        lastRelief = nil
        Task {
            let result = await Task.detached { MemoryService.freeUpMemory() }.value
            relieving = false
            snap = MemoryService.snapshot()
            helperInstalled = PrivilegedHelper.isInstalled()
            if result.purgeSucceeded {
                let gained = result.usedAfter < result.usedBefore ? result.usedBefore - result.usedAfter : 0
                lastRelief = "Dosya önbelleği temizlendi. \(Int64(gained).formattedBytes) bellek serbest bırakıldı."
            } else if !PrivilegedHelper.isInstalled() {
                lastRelief = "Yardımcı kurulamadı (izin alınamadı). Terminal'de deneyin: sudo purge"
            } else {
                lastRelief = "Önbellek temizlenemedi. Terminal'de deneyin: sudo purge"
            }
        }
    }

    private func uninstallHelper() {
        Task {
            let removed = await Task.detached { !PrivilegedHelper.isInstalled() || PrivilegedHelper.uninstall() }.value
            helperInstalled = !removed
            if removed { lastRelief = "Önbellek yardımcısı kaldırıldı." }
        }
    }
}