import SwiftUI

/// Pre-practice teaching screen — an audio-first, swipeable 5-beat story player
/// (LectureStoryPlayerView) that hands off into the live practice flow.
///
/// Session setup is now friction-aware:
/// • FIRST play (lecture not yet completed): NO settings screen. The session
///   config is auto-resolved from the user's onboarding profile via
///   `SessionConfig.recommended`, and the player shows a brief "playing with
///   your profile settings" micro-label. The profile is read-only here.
/// • REPLAY (lecture already completed): a lightweight `LectureReplaySetupView`
///   sheet appears first so the user can tweak coach + difficulty for THIS
///   session (optionally saving as their new default), then playback starts.
struct LectureDetailSheet: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  let lecture: Lecture

  enum Route: Hashable {
    case replaySetup
    case lecture
    case handoff
    case practice(SessionConfig)
    case results(SessionResult)
    case quiz
  }
  @State private var route: Route?

  /// Per-session overrides chosen on the replay setup sheet. Nil on a first
  /// play, where everything resolves from the onboarding profile.
  @State private var sessionCoach: CoachPersona?
  @State private var sessionTier: DifficultyTier?

  /// True when the session config was auto-resolved from the profile (first
  /// play) — drives the brief micro-label in the player.
  @State private var autoConfigured = false

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          Theme.bg.ignoresSafeArea()
          switch route {
          case .replaySetup: replaySetupScreen
          case .lecture: lecturePlayer
          case .handoff: handoffScreen
          case .practice(let cfg): practiceScreen(cfg: cfg)
          case .results(let r): resultsScreen(result: r)
          case .quiz: quizScreen
          case nil: Color.clear
          }
        }
        .toolbar { toolbarContent }
        .toolbarVisibility(showsChrome ? .automatic : .hidden, for: .navigationBar)
      }
      .onAppear { decideInitialRouteIfNeeded() }
    }
    .trackView("LectureDetailSheet")
  }

  /// On first appearance, branch on completion: replay → setup sheet, first
  /// play → straight into the auto-configured player.
  private func decideInitialRouteIfNeeded() {
    guard route == nil else { return }
    if app.isCompleted(lecture) {
      route = .replaySetup
    } else {
      autoConfigured = true
      route = .lecture
    }
  }

  /// The immersive story player + handoff + replay setup hide the sheet's nav
  /// chrome; practice/results/quiz keep the close button.
  private var showsChrome: Bool {
    switch route {
    case .lecture, .handoff, .replaySetup, nil: return false
    default: return true
    }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    if showsChrome {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
        }
        .tint(Theme.textMuted)
      }
    }
  }

  // MARK: - Replay setup (lightweight, completed lectures only)

  private var replaySetupScreen: some View {
    LectureReplaySetupView(
      lecture: lecture,
      initialCoach: app.selectedCoach,
      initialTier: app.difficultyTier,
      onPlay: { coach, tier in
        sessionCoach = coach
        sessionTier = tier
        autoConfigured = false
        withAnimation { route = .lecture }
      },
      onCancel: { dismiss() }
    )
  }

  // MARK: - Lecture (story player)

  private var lecturePlayer: some View {
    LectureStoryPlayerView(
      lecture: lecture,
      coachOverride: sessionCoach,
      showAutoConfigLabel: autoConfigured,
      onPractice: { withAnimation { route = .handoff } },
      onSkipToPractice: { route = .practice(resolvedConfig()) },
      onExit: { dismiss() }
    )
  }

  // MARK: - Handoff (energizing, sets the scene → live practice)

  private var handoffScreen: some View {
    LectureHandoffView(
      lecture: lecture,
      coach: sessionCoach ?? app.selectedCoach,
      partner: app.selectedPersona,
      setting: app.selectedSetting,
      onBegin: { route = .practice(resolvedConfig()) },
      onClose: { dismiss() }
    )
  }

  /// Build the session config from the onboarding profile, then apply any
  /// per-session replay overrides. The profile itself is never mutated here
  /// (only the explicit "Save as my default" toggle persists, in the sheet).
  private func resolvedConfig() -> SessionConfig {
    var cfg = SessionConfig.recommended(from: app, lecture: lecture)
    if let coach = sessionCoach { cfg.coach = coach.style }
    if let tier = sessionTier { cfg.tier = tier }
    return cfg
  }

  // MARK: - Practice

  private func practiceScreen(cfg: SessionConfig) -> some View {
    LivePracticeView(
      lecture: lecture,
      config: cfg,
      onFinish: { result in
        app.completePractice(lecture, result: result)
        route = .results(result)
      },
      onClose: { route = .lecture }
    )
  }

  // MARK: - Results

  private func resultsScreen(result: SessionResult) -> some View {
    ResultsView(
      result: result, lecture: lecture,
      onReplay: {
        sessionCoach = nil
        sessionTier = nil
        route = .replaySetup
      },
      onQuiz: { route = .quiz },
      onDone: { dismiss() })
  }

  // MARK: - Quiz

  private var quizScreen: some View {
    QuizView(
      lecture: lecture,
      onDone: { correct in
        app.recordQuiz(lecture, correct: correct)
        dismiss()
      })
  }
}

#Preview {
  LectureDetailSheet(lecture: Curriculum.lectures.first!)
    .environment(AppState.preview)
}
