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
        .preferredColorScheme(.dark)
        .dynamicTypeSize(appliedTypeSize)
        .tint(Theme.accent)
        .task {
          await appState.bootstrap()
          CharmsterSuperwall.identify(userId: appState.userId)
          NotificationManager.applyDailyReminder(
            profile: appState.profile, coachName: appState.selectedCoach.humanName)
        }
    }
  }

  /// Bumps every Text in the app one notch when the user picks "Large".
  private var appliedTypeSize: DynamicTypeSize {
    appState.profile.textSize == "large" ? .xLarge : .large
  }
}
