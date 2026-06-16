import SwiftUI

/// Pre-practice teaching screen — now an audio-first, swipeable 5-beat story
/// player (LectureStoryPlayerView) that hands off into the existing live
/// practice flow. The legacy stacked text-block UI was replaced; routing,
/// configurator, practice, results, and quiz handoff are preserved.
struct LectureDetailSheet: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  let lecture: Lecture

  enum Route {
    case lecture, handoff, configurator
    case practice(SessionConfig)
    case results(SessionResult)
    case quiz
  }
  @State private var route: Route = .lecture

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          Theme.bg.ignoresSafeArea()
          switch route {
          case .lecture: lecturePlayer
          case .handoff: handoffScreen
          case .configurator: configuratorScreen
          case .practice(let cfg): practiceScreen(cfg: cfg)
          case .results(let r): resultsScreen(result: r)
          case .quiz: quizScreen
          }
        }
        .toolbar { toolbarContent }
        .toolbarVisibility(showsChrome ? .automatic : .hidden, for: .navigationBar)
      }
    }
    .trackView("LectureDetailSheet")
  }

  /// The immersive story player + handoff hide the sheet's nav chrome; the
  /// configurator/practice/results/quiz screens keep the close button.
  private var showsChrome: Bool {
    switch route {
    case .lecture, .handoff: return false
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

  // MARK: - Lecture (story player)

  private var lecturePlayer: some View {
    LectureStoryPlayerView(
      lecture: lecture,
      onPractice: { withAnimation { route = .handoff } },
      onSkipToPractice: { route = .configurator },
      onExit: { dismiss() }
    )
  }

  // MARK: - Handoff (energizing, sets the scene → live practice)

  private var handoffScreen: some View {
    LectureHandoffView(
      lecture: lecture,
      coach: app.selectedCoach,
      partner: app.selectedPersona,
      setting: app.selectedSetting,
      onBegin: { route = .configurator },
      onClose: { dismiss() }
    )
  }

  // MARK: - Configurator

  private var configuratorScreen: some View {
    PracticeConfiguratorView(lecture: lecture) { cfg in
      route = .practice(cfg)
    } onCancel: {
      route = .lecture
    }
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
