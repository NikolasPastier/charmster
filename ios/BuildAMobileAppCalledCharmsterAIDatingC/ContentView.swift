import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Group {
            ZStack {
                Theme.background.ignoresSafeArea()
                if app.hasOnboarded {
                    MainTabView()
                } else {
                    OnboardingFlowView()
                }
            }
            .animation(.smooth(duration: 0.4), value: app.hasOnboarded)
        }
        .trackView("ContentView")
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
