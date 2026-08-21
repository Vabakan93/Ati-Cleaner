import SwiftUI

@main
struct MacCleanerApp: App {
    var body: some Scene {
        WindowGroup("Ati Cleaner") {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .tint(Theme.accent)
        }
        .windowStyle(.titleBar)
    }
}