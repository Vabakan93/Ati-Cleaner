import SwiftUI
import MacCleanerCore

struct DashboardView: View {
    @Binding var selection: AppSection?
    @State private var disk: DiskStatus?
    @State private var memory: MemoryStatus?
    @StateObject private var smartScan = SmartScanViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HeroHeader(
                    icon: "gauge",
                    title: "Ati Cleaner",
                    subtitle: "Mac'inizi temizleyin, alan kazanın ve performansı artırın.",
                    tint: Theme.dashboardColor,
                    actionTitle: "Hızlı\nTarama",
                    actionIcon: "arrow.clockwise",
                    actionEnabled: !smartScan.isScanning,
                    action: { smartScan.scan() }
                )

                SmartScanCard(viewModel: smartScan)

                if let memory {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bellek")
                            .font(.title2.bold())
                        HStack(spacing: 16) {
                            StatBox(title: "Toplam", value: formattedByteCount(Int64(memory.total)))
                            StatBox(title: "Kullanılan", value: formattedByteCount(Int64(memory.used)))
                            StatBox(title: "Boş", value: formattedByteCount(Int64(memory.free)))
                            StatBox(title: "Sıkıştırılmış", value: formattedByteCount(Int64(memory.compressed)))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Hızlı Eylemler")
                        .font(.title2.bold())
                    HStack(spacing: 16) {
                        QuickActionButton(
                            title: "Hızlı Tarama",
                            subtitle: "Sistem çöpünü tara",
                            icon: "bolt",
                            action: { selection = .junk }
                        )
                        QuickActionButton(
                            title: "Çift Dosyalar",
                            subtitle: "Yinelenenleri bul",
                            icon: "doc.on.doc",
                            action: { selection = .duplicates }
                        )
                        QuickActionButton(
                            title: "Büyük Dosyalar",
                            subtitle: "Alan yiyenleri bul",
                            icon: "doc.richtext",
                            action: { selection = .largeFiles }
                        )
                        QuickActionButton(
                            title: "Bellek Temizle",
                            subtitle: "Purge çalıştır",
                            icon: "memorychip",
                            action: { selection = .memory }
                        )
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            disk = DiskUsage.currentStatus()
            memory = MemoryInfo.currentStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            disk = DiskUsage.currentStatus()
            memory = MemoryInfo.currentStatus()
        }
    }
}

struct DiskCard: View {
    let status: DiskStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Disk Durumu")
                .font(.title2.bold())
            HStack {
                Gauge(value: status.usedPercentage) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryCircular)
                .tint(status.usedPercentage > 0.85 ? .red : status.usedPercentage > 0.7 ? .orange : .green)
                .scaleEffect(1.4)
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Kullanılan: \(formattedByteCount(status.used))")
                        .font(.headline)
                    Text("Boş: \(formattedByteCount(status.available))")
                        .font(.headline)
                    Text("Toplam: \(formattedByteCount(status.total))")
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 16)

                Spacer()
            }
            ProgressView(value: status.usedPercentage)
                .tint(status.usedPercentage > 0.85 ? .red : status.usedPercentage > 0.7 ? .orange : .green)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
}