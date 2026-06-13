import SuperwallKit
import SwiftUI

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
        .preferredColorScheme(appliedColorScheme)
        .dynamicTypeSize(appliedTypeSize)
        .tint(Theme.accent)
        .task {
          await appState.bootstrap()
          CharmsterSuperwall.identify(userId: appState.userId)
          NotificationManager.applyDailyReminder(profile: appState.profile)
        }
    }
  }

  /// System / Light / Dark from `profile.themePreference`. Drives the app-root
  /// color scheme so the Theme picker in Settings actually re-skins the app.
  private var appliedColorScheme: ColorScheme? {
    switch appState.profile.themePreference {
    case "light": return .light
    case "dark": return .dark
    default: return nil  // "system"
    }
  }

  /// Bumps every Text in the app one notch when the user picks "Large".
  private var appliedTypeSize: DynamicTypeSize {
    appState.profile.textSize == "large" ? .xLarge : .large
  }
}
