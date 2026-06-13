import SwiftUI

/// Pre-practice teaching screen — 5 beats + TTS narration + coach-style framing.
struct LectureDetailSheet: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  let lecture: Lecture

  enum Route {
    case lecture, configurator
    case practice(SessionConfig)
    case results(SessionResult)
    case quiz
  }
  @State private var route: Route = .lecture
  @State private var narrator = TeachingNarrator()
  @State private var content: TeachingContent = TeachingContent(
    hook: "", coreInsight: "", goodExample: "", badExample: "",
    practicalTakeaway: "", practiceHandoff: ""
  )

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          Theme.bg.ignoresSafeArea()
          switch route {
          case .lecture: lectureScreen
          case .configurator: configuratorScreen
          case .practice(let cfg): practiceScreen(cfg: cfg)
          case .results(let r): resultsScreen(result: r)
          case .quiz: quizScreen
          }
        }
        .toolbar {
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
      .onAppear { loadContent() }
      .onDisappear { narrator.stop() }
    }
    .trackView("LectureDetailSheet")
  }

  private func loadContent() {
    content = LectureContentStore.shared.teaching(for: lecture, coach: app.coachMode)
    app.recordWatched(lecture)
  }

  // MARK: - Lecture (5 beats + narration)

  private var lectureScreen: some View {
    ScrollView {
      VStack(spacing: 16) {
        header
        narratorBar
        beatCard(title: "Hook", text: content.hook, icon: "sparkles")
        beatCard(title: "Core insight", text: content.coreInsight, icon: "lightbulb.fill")
        goodVsBadCard
        beatCard(title: "Takeaway", text: content.practicalTakeaway, icon: "checkmark.seal.fill")
        beatCard(title: "Practice handoff", text: content.practiceHandoff, icon: "play.circle.fill")

        AuraButton(title: "Practice this", systemImage: "waveform") {
          route = .configurator
        }
        .padding(.top, 6)

        GlassButton(title: "Skip to quiz", systemImage: "questionmark.circle") {
          route = .quiz
        }
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 18)
      .padding(.bottom, 30)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        TagPill(label: "Lecture \(lecture.displayNumber)", systemImage: "book.fill")
        if lecture.isCapstone {
          TagPill(label: "CAPSTONE", systemImage: "crown.fill", tone: .gold)
        }
        TagPill(label: "\(lecture.minutes) min", systemImage: "clock.fill")
        Spacer()
      }
      Text(lecture.title)
        .font(.system(size: 28, weight: .heavy))
        .foregroundStyle(Theme.text)
      Text(lecture.scenario)
        .font(.system(size: 15))
        .foregroundStyle(Theme.textMuted)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var narratorBar: some View {
    GlassCard(padding: 14) {
      HStack(spacing: 12) {
        Button {
          if narrator.isSpeaking {
            narrator.pauseOrResume()
          } else {
            narrator.speak(content.narrationScript, coach: app.coachMode)
          }
        } label: {
          Image(systemName: narrator.isSpeaking ? "pause.fill" : "play.fill")
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(.black)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Theme.accent))
        }
        .buttonStyle(.plain)

        VStack(alignment: .leading, spacing: 4) {
          Text("Narrated by \(app.coachMode.title)")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.text)
          ProgressView(value: narrator.progress)
            .tint(Theme.accent)
        }
        Button {
          narrator.stop()
        } label: {
          Image(systemName: "stop.fill").foregroundStyle(Theme.textMuted)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func beatCard(title: String, text: String, icon: String) -> some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        SectionHeader(title: title, systemImage: icon)
        Text(text)
          .font(.system(size: 15))
          .foregroundStyle(Theme.text)
          .lineSpacing(3)
      }
    }
  }

  private var goodVsBadCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "Good vs. bad", systemImage: "scale.3d")
        VStack(spacing: 12) {
          exampleBlock(label: "GOOD", tone: Theme.good, text: content.goodExample)
          exampleBlock(label: "BAD", tone: Theme.bad, text: content.badExample)
        }
      }
    }
  }

  private func exampleBlock(label: String, tone: Color, text: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.system(size: 11, weight: .heavy)).tracking(1.6)
        .foregroundStyle(tone)
      Text(text)
        .font(.system(size: 14))
        .foregroundStyle(Theme.text)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(tone.opacity(0.10))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(tone.opacity(0.3), lineWidth: 1)
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
