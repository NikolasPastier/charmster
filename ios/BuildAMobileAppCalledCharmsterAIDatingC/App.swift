import SwiftUI

@main
struct CharmsterApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(Theme.pink)
        }
    }
}
