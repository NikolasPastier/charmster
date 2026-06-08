import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var app
    @State private var showSplash: Bool = true

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

            if showSplash {
                LaunchSplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.smooth(duration: 0.4), value: app.hasOnboarded)
        .task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.smooth(duration: 0.5)) { showSplash = false }
        }
        .trackView("ContentView")
    }
}

private struct LaunchSplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            AuraBackground().opacity(0.6)

            VStack(spacing: 22) {
                BrandLogo(size: .hero(150))
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
                VStack(spacing: 6) {
                    Text("CHARMSTER")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .tracking(6)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Practice the real thing.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .onAppear {
            withAnimation(.smooth(duration: 0.7)) { appeared = true }
        }
    }
}

#Preview {
    ContentView().environment(AppState()).preferredColorScheme(.dark)
}
