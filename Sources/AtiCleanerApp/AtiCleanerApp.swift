import SwiftUI
import AtiCleanerCore

@main
struct AtiCleanerApp: App {
    init() {
        UserDefaults.standard.register(defaults: [SafetyPolicy.excludedVolumesKey: "gamess,Yedek"])
        if CommandLine.arguments.contains("--purge") {
            let token = (try? String(contentsOfFile: "/var/tmp/aticleaner-purge-trigger", encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ok = MemoryService.runPurge()
            let marker = "/var/tmp/aticleaner-purge-result-" + token
            try? (ok ? "ok" : "fail").write(toFile: marker, atomically: true, encoding: .utf8)
            exit(ok ? 0 : 1)
        }
    }
    var body: some Scene {
        WindowGroup("Ati Cleaner") {
            RootView()
                .frame(minWidth: 1040, minHeight: 700)
                .tint(Theme.accent)
        }
        .windowStyle(.titleBar)
    }
}
