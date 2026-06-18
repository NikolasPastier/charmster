import SwiftUI

/// Root container. Routes between Onboarding and the main TabView based on AppState.
struct RootView: View {
  @Environment(AppState.self) private var app
  @State private var showSplash = true

  var body: some View {
    ZStack {
      Group {
        if !app.hasCompletedOnboarding {
          OnboardingFlowView()
            .transition(.opacity)
        } else {
          MainTabView()
            .transition(.opacity)
        }
      }
      .animation(.smooth(duration: 0.45), value: app.hasCompletedOnboarding)

      if showSplash {
        SplashView()
          .transition(.opacity)
          .zIndex(1)
      }
    }
    .task {
      try? await Task.sleep(for: .seconds(1.7))
      withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
    }
  }
}

struct MainTabView: View {
  @Environment(AppState.self) private var app

  var body: some View {
    TabView {
      RoadmapView()
        .tabItem { Label("Path", systemImage: "map.fill") }

      PracticeHubView()
        .tabItem { Label("Practice", systemImage: "waveform") }

      ReviewHubView()
        .tabItem { Label("Review", systemImage: "arrow.triangle.2.circlepath") }

      ProfileView()
        .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }

      SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
    }
    .tint(Theme.accent)
    .overlay(alignment: .top) {
      if let pb = app.lastPersonalBest {
        PersonalBestToast(dimension: pb.dimension, value: pb.value)
          .padding(.top, 8)
          .transition(.move(edge: .top).combined(with: .opacity))
          .onAppear {
            #if canImport(UIKit)
              UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
              app.clearPersonalBestToast()
            }
          }
      }
    }
    .animation(
      .spring(response: 0.42, dampingFraction: 0.82), value: app.lastPersonalBest?.dimension)
  }
}

#Preview {
  RootView()
    .environment(AppState.preview)
}
