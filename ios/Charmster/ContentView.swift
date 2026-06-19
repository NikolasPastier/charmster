import SwiftUI

/// Root container. Routes between Onboarding and the main TabView based on AppState.
struct RootView: View {
  @Environment(AppState.self) private var app
  @State private var showSplash = true
  #if DEBUG
  @State private var debugLecture: Lecture?

  // Set via UserDefaults before launch:
  //   PlistBuddy -c "Add :debug_skip_onboarding bool YES" <container>/Library/Preferences/app.10x.charmster.plist
  private var debugSkipsOnboarding: Bool {
    UserDefaults.standard.bool(forKey: "debug_skip_onboarding")
      || ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
  }
  #endif

  private var isShowingOnboarding: Bool {
    #if DEBUG
    if debugSkipsOnboarding { return false }
    #endif
    return !app.hasCompletedOnboarding
  }

  var body: some View {
    ZStack {
      Group {
        if isShowingOnboarding {
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
    #if DEBUG
    .sheet(item: $debugLecture) { lec in
      LectureDetailSheet(lecture: lec)
        .environment(app)
        .presentationDetents([.large])
    }
    #endif
    .task {
      // Shorter splash in debug-navigate mode so the lecture opens faster.
      #if DEBUG
      let splashDelay: Double = debugSkipsOnboarding ? 0.4 : 1.7
      #else
      let splashDelay: Double = 1.7
      #endif
      try? await Task.sleep(for: .seconds(splashDelay))
      withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
      #if DEBUG
      // Pass --lecture-id <id> on the simulator command line to auto-open a
      // specific lecture player for logging/screenshot capture.
      let args = ProcessInfo.processInfo.arguments
      if let idx = args.firstIndex(of: "--lecture-id"), idx + 1 < args.count {
        let lid = args[idx + 1]
        try? await Task.sleep(for: .seconds(0.4))
        if let lec = Curriculum.lecture(id: lid) {
          debugLecture = lec
        } else {
          print("[LEC4] --lecture-id \(lid) not found in curriculum")
        }
      }
      #endif
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
