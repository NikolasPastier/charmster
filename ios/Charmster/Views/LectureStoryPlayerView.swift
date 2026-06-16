import SwiftUI

/// Audio-first, swipeable story-card lecture player.
///
/// One beat per full-screen card. The narration plays as AUDIO in the selected
/// coach's voice; on screen we show only the beat's visual + a single signal
/// phrase (never the full script). Tap/swipe to advance, hold to pause, slim
/// segmented Aura progress bar. Captions OFF by default (redundancy principle),
/// toggleable for accessibility. Skippable for returning users.
///
/// Avatar beats (hook + takeaway) reuse `CoachAvatarView` — talking loop under
/// the per-beat audio, with the clip-optional still fallback already built in.
/// Insight/GoodVsBad beats show the teaching visual with coach voiceover and a
/// small picture-in-picture avatar.
struct LectureStoryPlayerView: View {
  @Environment(AppState.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let lecture: Lecture
  let onPractice: () -> Void
  let onSkipToPractice: () -> Void

  @State private var story: LectureStory?
  @State private var index: Int = 0
  @State private var narrator = LectureBeatNarrator()
  @State private var captionsOn: Bool = false
  @State private var isPaused: Bool = false

  // Recall beat state
  @State private var recallChoice: Int?

  private var coach: CoachPersona { app.selectedCoach }

  var body: some View {
      Group {
              ZStack {
          Theme.bg.ignoresSafeArea()
          if let story {
            content(story: story)
          } else {
            ProgressView().tint(Theme.accent)
          }
              }
              .onAppear {
          buildStoryIfNeeded()
          captionsOn = app.profile.captionsEnabled ? false : false  // default OFF regardless
          startBeat()
              }
              .onDisappear { narrator.stop() }
      }
      .trackView("LectureStoryPlayerView")
  }

  // MARK: - Build

  private func buildStoryIfNeeded() {
    guard story == nil else { return }
    story = LectureStoryBuilder.build(for: lecture, coach: coach)
    app.recordWatched(lecture)
  }

  private var beats: [LectureBeat] { story?.beats ?? [] }
  private var currentBeat: LectureBeat? { beats.indices.contains(index) ? beats[index] : nil }
  private var isLast: Bool { index >= beats.count - 1 }

  // MARK: - Content

  @ViewBuilder
  private func content(story: LectureStory) -> some View {
    VStack(spacing: 0) {
      topBar
      progressBar
      ZStack {
        ForEach(Array(beats.enumerated()), id: \.element.id) { i, beat in
          if i == index {
            beatCard(beat: beat, mode: story.conversationMode)
              .transition(.opacity)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .onTapGesture { advanceFromTap() }
      .gesture(
        DragGesture(minimumDistance: 24)
          .onEnded { value in
            if value.translation.width < -40 {
              advanceFromTap()
            } else if value.translation.width > 40 {
              goBack()
            }
          }
      )
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 0.25)
          .onChanged { _ in holdPause() }
          .onEnded { _ in holdResume() }
      )
      bottomBar(beat: currentBeat)
    }
  }

  // MARK: - Top bar (skip + captions)

  private var topBar: some View {
    HStack(spacing: 14) {
      Button {
        captionsOn.toggle()
      } label: {
        Image(systemName: captionsOn ? "captions.bubble.fill" : "captions.bubble")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(captionsOn ? Theme.accent : Theme.textMuted)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Toggle captions")

      Spacer()

      Button {
        narrator.stop()
        onSkipToPractice()
      } label: {
        HStack(spacing: 5) {
          Text("Skip to practice").font(.system(size: 13, weight: .bold))
          Image(systemName: "forward.fill").font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(Theme.textMuted)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Theme.surfaceRaised))
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 18)
    .padding(.top, 8)
    .padding(.bottom, 10)
  }

  // MARK: - Progress bar (one segment per beat, Aura gradient)

  private var progressBar: some View {
    HStack(spacing: 5) {
      ForEach(beats.indices, id: \.self) { i in
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(Theme.surfaceRaised)
            Capsule()
              .fill(Theme.auraGradient)
              .frame(width: geo.size.width * segmentFill(i))
          }
        }
        .frame(height: 4)
      }
    }
    .padding(.horizontal, 18)
    .padding(.bottom, 6)
    .animation(.easeInOut(duration: 0.25), value: index)
    .animation(.linear(duration: 0.2), value: narrator.progress)
  }

  private func segmentFill(_ i: Int) -> CGFloat {
    if i < index { return 1 }
    if i > index { return 0 }
    return CGFloat(max(0.04, narrator.progress))
  }

  // MARK: - Beat card

  @ViewBuilder
  private func beatCard(beat: LectureBeat, mode: ConversationMode) -> some View {
    VStack(spacing: 20) {
      beatVisual(beat: beat, mode: mode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      // Signal phrase — the ONLY narration-derived text shown by default.
      if beat.visual != .recallQuestion {
        Text(beat.signalPhrase)
          .font(.system(size: 22, weight: .heavy))
          .multilineTextAlignment(.center)
          .foregroundStyle(Theme.text)
          .padding(.horizontal, 24)
      }

      if captionsOn {
        Text(beat.narrationText)
          .font(.system(size: 13))
          .foregroundStyle(Theme.textMuted)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 26)
          .transition(.opacity)
      }
    }
    .padding(.vertical, 10)
  }

  @ViewBuilder
  private func beatVisual(beat: LectureBeat, mode: ConversationMode) -> some View {
    switch beat.visual {
    case .avatar:
      avatarStage(big: true)
    case .contrastCards:
      VStack(spacing: 18) {
        avatarStage(big: false)
        InsightSignalCard(
          signalPhrase: beat.signalPhrase,
          supporting: insightChips(mode: mode)
        )
        .padding(.horizontal, 18)
      }
    case .spokenLineCards, .chatMockup:
      VStack(spacing: 14) {
        avatarStage(big: false)
        if let good = beat.goodExample, let bad = beat.badExample {
          GoodBadContrastFrame(mode: mode, good: good, bad: bad)
            .padding(.horizontal, 18)
        }
      }
    case .recallQuestion:
      if let recall = beat.recall {
        recallView(recall)
      }
    }
  }

  private func insightChips(mode: ConversationMode) -> [String] {
    switch lecture.skill {
    case "Opening": return ["Voice", "Eyes", "Timing"]
    case "Presence": return ["Notice", "Breathe", "Stay"]
    case "Frame": return ["Tone", "Hold", "Half-smile"]
    case "Flow": return ["Listen", "Callback", "Space"]
    default: return mode == .texting ? ["Send", "Wait", "Read"] : ["Be present"]
    }
  }

  // MARK: - Avatar stage (reuses CoachAvatarView; PiP for non-avatar beats)

  @ViewBuilder
  private func avatarStage(big: Bool) -> some View {
    let speaking = narrator.isSpeaking && !isPaused
    let size: CGFloat = big ? 260 : 120
    CoachAvatarView(
      coach: coach,
      baseState: speaking ? .talking : .idle
    )
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: big ? 28 : 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: big ? 28 : 20, style: .continuous)
        .stroke(Theme.border, lineWidth: 1)
    )
    .auraGlow(radius: big ? 26 : 14, intensity: speaking ? 0.5 : 0.25)
    .animation(.easeInOut(duration: 0.3), value: speaking)
  }

  // MARK: - Recall view (active-recall tap)

  @ViewBuilder
  private func recallView(_ recall: RecallCheck) -> some View {
    VStack(spacing: 16) {
      avatarStage(big: false)
      Text(recall.question)
        .font(.system(size: 22, weight: .heavy))
        .multilineTextAlignment(.center)
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 22)

      VStack(spacing: 10) {
        ForEach(recall.options.indices, id: \.self) { i in
          recallOption(recall, i)
        }
      }
      .padding(.horizontal, 18)

      if let choice = recallChoice {
        let correct = choice == recall.correctIndex
        VStack(spacing: 6) {
          HStack(spacing: 6) {
            Image(systemName: correct ? "checkmark.seal.fill" : "info.circle.fill")
              .foregroundStyle(correct ? Theme.good : Theme.warn)
            Text(correct ? "Nailed it" : "Not quite")
              .font(.system(size: 15, weight: .heavy))
              .foregroundStyle(correct ? Theme.good : Theme.warn)
          }
          Text(recall.why)
            .font(.system(size: 14))
            .foregroundStyle(Theme.textMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
          if correct {
            HStack(spacing: 5) {
              Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
              Text("+Aura").font(.system(size: 12, weight: .heavy))
            }
            .foregroundStyle(Theme.aura)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Theme.aura.opacity(0.12)))
          }
        }
        .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.25), value: recallChoice)
  }

  @ViewBuilder
  private func recallOption(_ recall: RecallCheck, _ i: Int) -> some View {
    let answered = recallChoice != nil
    let isChosen = recallChoice == i
    let isCorrect = i == recall.correctIndex
    let tone: Color = {
      guard answered else { return Theme.border }
      if isCorrect { return Theme.good }
      if isChosen { return Theme.bad }
      return Theme.border
    }()
    Button {
      guard recallChoice == nil else { return }
      recallChoice = i
      app.awardRecallPing(correct: isCorrect)
    } label: {
      HStack {
        Text(recall.options[i])
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Theme.text)
          .multilineTextAlignment(.leading)
        Spacer()
        if answered, isCorrect {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.good)
        } else if answered, isChosen {
          Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.bad)
        }
      }
      .padding(.horizontal, 16).padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(answered && (isCorrect || isChosen) ? tone.opacity(0.10) : Theme.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(tone.opacity(answered ? 0.5 : 1), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(answered)
  }

  // MARK: - Bottom bar (handoff CTA on last beat)

  @ViewBuilder
  private func bottomBar(beat: LectureBeat?) -> some View {
    VStack(spacing: 10) {
      if isLast {
        AuraButton(title: "Start practice", systemImage: "waveform") {
          narrator.stop()
          onPractice()
        }
      } else if beat?.kind == .recallCheck {
        AuraButton(
          title: recallChoice == nil ? "Pick one to continue" : "Continue",
          systemImage: "arrow.right",
          enabled: recallChoice != nil
        ) {
          advanceFromTap()
        }
      } else {
        HStack {
          Button {
            goBack()
          } label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(index == 0 ? Theme.textFaint : Theme.textMuted)
          }
          .buttonStyle(.plain)
          .disabled(index == 0)
          Spacer()
          Text("Tap to continue")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textFaint)
          Spacer()
          Button {
            advanceFromTap()
          } label: {
            Image(systemName: "chevron.right")
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(Theme.accent)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 8)
    .padding(.bottom, 18)
  }

  // MARK: - Playback control

  private func startBeat() {
    guard let beat = currentBeat else { return }
    isPaused = false
    narrator.speak(beat, coach: coach.style) {
      // Auto-advance after audio ends — except the recall beat, which waits
      // for a tap so the user actually answers.
      if beat.kind == .recallCheck { return }
      if !isLast { advance() }
    }
  }

  private func advanceFromTap() {
    // On the recall beat, a tap should not skip past an unanswered question.
    if currentBeat?.kind == .recallCheck, recallChoice == nil { return }
    if isLast {
      narrator.stop()
      onPractice()
      return
    }
    advance()
  }

  private func advance() {
    guard index < beats.count - 1 else { return }
    narrator.stop()
    withAnimation(.easeInOut(duration: 0.3)) { index += 1 }
    recallChoice = nil
    startBeat()
  }

  private func goBack() {
    guard index > 0 else { return }
    narrator.stop()
    withAnimation(.easeInOut(duration: 0.3)) { index -= 1 }
    recallChoice = nil
    startBeat()
  }

  private func holdPause() {
    guard !isPaused else { return }
    isPaused = true
    narrator.pause()
  }

  private func holdResume() {
    guard isPaused else { return }
    isPaused = false
    narrator.resume()
  }
}

#Preview {
  LectureStoryPlayerView(
    lecture: Curriculum.lectures.first!,
    onPractice: {},
    onSkipToPractice: {}
  )
  .environment(AppState.preview)
}
