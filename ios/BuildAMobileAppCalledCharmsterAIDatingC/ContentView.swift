import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            AuraBackground()
            if app.hasOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: app.hasOnboarded)
        .trackView("ContentView")
    }
}

#Preview {
    ContentView().environment(AppState()).preferredColorScheme(.dark)
}
