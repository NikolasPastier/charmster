import SwiftUI
import SuperwallKit

@main
struct CharmsterApp: App {
    @State private var appState = AppState()

    init() {
        CharmsterSuperwall.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task {
                    await appState.bootstrap()
                    CharmsterSuperwall.identify(userId: appState.userId)
                }
        }
    }
}
