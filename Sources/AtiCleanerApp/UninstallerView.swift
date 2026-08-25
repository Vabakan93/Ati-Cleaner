import SwiftUI
import AtiCleanerCore

@MainActor struct UninstallerView: View {
    @State private var apps: [InstalledApp] = []
    @State private var query = ""
    @State private var removing = false
    @State private var pendingApp: InstalledApp?
    @State private var resultMessage: String?

    var filtered: [InstalledApp] { query.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(query) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "xmark.app", title: "Uygulama Kaldırıcı", subtitle: "Yüklü uygulamaları otomatik listeleyin ve seçtiklerinizi Çöp Kutusu'na taşıyın.", tint: Theme.uninstall)
            TextField("Uygulama ara…", text: $query).textFieldStyle(.roundedBorder)
            if removing {
                ProgressView("Uygulama kaldırılıyor…")
            } else if apps.isEmpty {
                ProgressView("Uygulamalar listeleniyor…")
            } else {
                List(filtered) { app in
                    HStack {
                        Image(systemName: "app.fill").foregroundStyle(Theme.uninstall)
                        VStack(alignment: .leading) {
                            Text(app.name).font(.headline)
                            Text(app.bundleIdentifier ?? app.path).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(app.size.formattedBytes).monospacedDigit().foregroundStyle(.secondary)
                        Button("Kaldır", role: .destructive) { pendingApp = app }
                        Button("Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)]) }
                    }
                }
            }
        }
        .padding(24)
        .task { apps = await Task.detached { AppScanner.installedApps() }.value }
        .alert(item: $pendingApp) { app in
            Alert(
                title: Text("\(app.name) kaldırılsın mı?"),
                message: Text("Uygulama Çöp Kutusu'na taşınacak. Kaldırmak istediğinize emin misiniz?"),
                primaryButton: .destructive(Text("Kaldır")) { uninstall(app) },
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
        .alert("İşlem Sonucu", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
    }

    private func uninstall(_ app: InstalledApp) {
        removing = true
        let path = app.path
        let name = app.name
        Task {
            let result = await Task.detached { FileUtilities.moveToTrash(paths: [path]) }.value
            removing = false
            apps.removeAll { $0.path == path }
            if result.failed.isEmpty {
                resultMessage = "\(name) Çöp Kutusu'na taşındı."
            } else {
                resultMessage = result.failed.map { "\($0.path): \($0.reason)" }.joined(separator: "\n")
            }
        }
    }
}