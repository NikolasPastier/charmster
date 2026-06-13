import SwiftUI

/// Root container. Routes between Onboarding and the main TabView based on AppState.
struct RootView: View {
  @Environment(AppState.self) private var app

  var body: some View {
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
  }
}

#Preview {
  RootView()
    .environment(AppState.preview)
}
