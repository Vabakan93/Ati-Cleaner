import SwiftUI
import MacCleanerCore

struct PermissionBanner: View {
    let paths: [String]
    let fdaGranted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: fdaGranted ? "lock.rotation" : "lock.shield")
                    .foregroundStyle(.orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    if fdaGranted {
                        Text("İzin verilmiş görünüyor ama erişim yok")
                            .font(.headline)
                        Text("Sistem Ayarları → Gizlilik ve Güvenlik → Tam Disk Erişimi listesinde Ati Cleaner'ı KAPATIP yeniden AÇIN (varsa eski girişleri de silin), sonra uygulamayı yeniden başlatın.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Bazı klasörlere erişilemedi — Tam Disk Erişimi gerekli")
                            .font(.headline)
                        Text("Sistem Ayarları → Gizlilik ve Güvenlik → Tam Disk Erişimi → Ati Cleaner'ı açın, sonra uygulamayı yeniden başlatın.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Button("Ayarları Aç") {
                    openFullDiskAccessSettings()
                }
                .buttonStyle(.bordered)
                Button("Uygulamayı Yeniden Başlat") {
                    relaunchApp()
                }
                .buttonStyle(.borderedProminent)
            }
            if paths.count <= 3 {
                HStack(spacing: 6) {
                    ForEach(paths, id: \.self) { path in
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3))
        )
    }

    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private func relaunchApp() {
        let appPath = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; open \"\(appPath)\""]
        try? process.run()
        NSApplication.shared.terminate(nil)
    }
}