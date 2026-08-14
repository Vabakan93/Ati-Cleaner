import SwiftUI

@main
struct AtiCleanerApp: App {
    var body: some Scene {
        WindowGroup("Ati Cleaner") {
            RootView()
                .frame(minWidth: 1040, minHeight: 700)
                .tint(Theme.accent)
        }
        .windowStyle(.titleBar)
    }
}
