import SwiftUI
import MacCleanerCore

@MainActor
final class MemoryViewModel: ObservableObject {
    @Published var status: MemoryStatus?
    @Published var isPurging = false
    @Published var purgeMessage: String?
    @Published var purgeError: String?

    func refresh() {
        status = MemoryInfo.currentStatus()
    }

    func purge() {
        guard !isPurging else { return }
        isPurging = true
        purgeMessage = nil
        purgeError = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let message = MemoryInfo.runPurge()
            DispatchQueue.main.async {
                self.isPurging = false
                if let message {
                    self.purgeError = message
                } else {
                    self.purgeMessage = "Bellek temizlendi"
                    self.refresh()
                }
            }
        }
    }
}

struct MemoryView: View {
    @StateObject private var viewModel = MemoryViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeroHeader(
                icon: "memorychip",
                title: "Bellek",
                subtitle: "RAM kullanımını izleyin ve sistem tarafından tutulan boş belleği boşaltın.",
                tint: Theme.memoryColor,
                actionTitle: "Temizle",
                actionIcon: "memorychip",
                actionEnabled: !viewModel.isPurging,
                action: viewModel.purge
            )

            if let status = viewModel.status {
                memoryGauge(status)
                statsGrid(status)

                VStack(alignment: .leading, spacing: 8) {
                    Label(status.pressureLevel, systemImage: "gauge")
                        .font(.headline)
                        .foregroundStyle(status.pressureLevel.contains("Kritik") ? .red : .green)

                    HStack(spacing: 12) {
                        Button {
                            viewModel.purge()
                        } label: {
                            if viewModel.isPurging {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Belleği Temizle (purge)", systemImage: "memorychip")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isPurging)

                        if let message = viewModel.purgeMessage {
                            Label(message, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        if let error = viewModel.purgeError {
                            Text("\(error) — Şifrenizi girip onaylamanız gerekebilir.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            } else {
                ProgressView("Bellek bilgisi alınıyor…")
            }

        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { viewModel.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refresh()
        }
    }

    private func memoryGauge(_ status: MemoryStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RAM Kullanımı")
                .font(.title2.bold())
            HStack {
                Gauge(value: status.usedPercentage) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryCircular)
                .tint(status.usedPercentage > 0.85 ? .red : status.usedPercentage > 0.7 ? .orange : .green)
                .scaleEffect(1.4)
                .frame(width: 90, height: 90)
                VStack(alignment: .leading, spacing: 4) {
                    Text("%\(Int(status.usedPercentage * 100)) kullanılıyor")
                        .font(.title3.bold())
                    Text("Kullanılan: \(formattedByteCount(Int64(status.used)))  /  Toplam: \(formattedByteCount(Int64(status.total)))")
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 14)
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func statsGrid(_ status: MemoryStatus) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatBox(title: "Toplam", value: formattedByteCount(Int64(status.total)))
            StatBox(title: "Kullanılan", value: formattedByteCount(Int64(status.used)))
            StatBox(title: "Boş", value: formattedByteCount(Int64(status.free)))
            StatBox(title: "Pasif", value: formattedByteCount(Int64(status.inactive)))
            StatBox(title: "Etkin", value: formattedByteCount(Int64(status.active)))
            StatBox(title: "Kablolu", value: formattedByteCount(Int64(status.wired)))
            StatBox(title: "Sıkıştırılmış", value: formattedByteCount(Int64(status.compressed)))
            StatBox(title: "Uygulama Belleği", value: formattedByteCount(Int64(status.total - status.free - status.inactive - status.wired)))
        }
    }
}