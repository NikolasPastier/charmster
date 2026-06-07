import SwiftUI

@main
struct CharmsterApp: App {
    @State private var appState = AppState()
    @State private var lectureStore = LectureContentStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(lectureStore)
                .preferredColorScheme(.dark)
                .tint(Theme.pink)
                .task { await lectureStore.loadIfNeeded() }
        }
    }
}
