import SwiftUI

/// Audio-first, swipeable story-card lecture player — restyled to the approved
/// **Aura** mockups: a deep Charmster base with a soft pink→gold radial glow
/// halo behind the coach, a slim segmented progress bar with an X exit + beat
/// timer up top, and the coach clip feathered full-bleed into the scene.
///
/// One beat per card. Narration plays as AUDIO in the selected coach's voice
/// (the ONLY audio); the coach VIDEO clips are purely visual and force-muted.
/// On screen we show only the beat's single signal phrase (never the full
/// script). Tap/swipe to advance, hold to pause. Captions OFF by default.
///
/// Avatar beats (hook + takeaway) show the coach TALKING loop full-bleed +
/// feathered + glow. Insight/GoodVsBad/Recall beats show the teaching visual /
/// question UI with coach voiceover and a small feathered IDLE picture-in-
/// picture. One talking take is chosen when the lecture opens and held for the
/// whole lecture. Reduced-motion / load / offline shows the coach still.
struct LectureStoryPlayerView: View {
  @Environment(AppState.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let lecture: Lecture
  /// Per-session coach override (from the replay setup sheet). When nil the
  /// player uses the user's default `app.selectedCoach`.
  var coachOverride: CoachPersona? = nil
  /// Show a brief "playing with your profile settings" micro-label on first
  /// play, when the session was auto-configured from the onboarding profile.
  var showAutoConfigLabel: Bool = false
  let onPractice: () -> Void
  let onSkipToPractice: () -> Void
  /// Exit the lecture (wired to the X). Defaults to no-op for previews.
  var onExit: () -> Void = {}

  @State private var story: LectureStory?
  @State private var index: Int = 0
  @State private var narrator = LectureBeatNarrator()
  @State private var captionsOn: Bool = false
  @State private var isPaused: Bool = false
  @State private var showProfileLabel: Bool = false

  /// Talking take chosen ONCE per lecture, held for the whole session.
  @State private var talkingTake: Int = 1

  // Recall beat state
  @State private var recallChoice: Int?

  private var coach: CoachPersona { coachOverride ?? app.selectedCoach }

  var body: some View {
    Group {
      ZStack {
        auraBackground
        if let story {
          content(story: story)
        } else {
          ProgressView().tint(Theme.accent)
        }
        if showProfileLabel {
          profileMicroLabel
        }
      }
      .onAppear {
        talkingTake = CoachClipCatalog.shared.randomTalkingTake()
        Task { await CoachClipCatalog.shared.preload(persona: coach, talkingTake: talkingTake) }
        buildStoryIfNeeded()
        captionsOn = false  // default OFF (redundancy principle)
        startBeat()
        showProfileMicroLabelIfNeeded()
      }
      .onDisappear { narrator.stop() }
    }
    .trackView("LectureStoryPlayerView")
  }

  // MARK: - Aura background (deep base + soft pink→gold halo, vignette edges)

  private var auraBackground: some View {
    let avatarBeat = currentBeat?.visual == .avatar
    let warm: Double = (narrator.isSpeaking && !isPaused) ? 0.55 : 0.32
    return ZStack {
      Color(hex: 0x0B0910).ignoresSafeArea()  // deep Charmster base

      // Soft Aura glow halo — pink blending to gold, heavily blurred, low
      // opacity, biased toward the upper third where the coach sits.
      RadialGradient(
        colors: [
          Theme.pink.opacity(avatarBeat ? warm : warm * 0.6),
          Theme.gold.opacity((avatarBeat ? warm : warm * 0.6) * 0.55),
          .clear,
        ],
        center: UnitPoint(x: 0.5, y: avatarBeat ? 0.34 : 0.3),
        startRadius: 30,
        endRadius: 460
      )
      .blur(radius: 90)
      .ignoresSafeArea()
      .animation(.easeInOut(duration: 0.6), value: warm)
      .animation(.easeInOut(duration: 0.4), value: avatarBeat)

      // Edge vignette darkening to near-black.
      RadialGradient(
        colors: [.clear, .clear, Color(hex: 0x0B0910).opacity(0.9)],
        center: .center,
        startRadius: 120,
        endRadius: 560
      )
      .ignoresSafeArea()
      .allowsHitTesting(false)
    }
  }

  // MARK: - Profile micro-label (first-play personalization cue)

  private var profileMicroLabel: some View {
    VStack {
      HStack(spacing: 7) {
        Image(systemName: "person.crop.circle.badge.checkmark")
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(Theme.accent)
        Text("Playing with your profile settings")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(Theme.text)
      }
      .padding(.horizontal, 14).padding(.vertical, 9)
      .background(Capsule().fill(Theme.surfaceRaised.opacity(0.92)))
      .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
      .shadow(color: .black.opacity(0.3), radius: 10, y: 3)
      .padding(.top, 86)
      Spacer()
    }
    .transition(.move(edge: .top).combined(with: .opacity))
    .allowsHitTesting(false)
  }

  /// Briefly surface the personalization cue on a first play, then fade it.
  private func showProfileMicroLabelIfNeeded() {
    guard showAutoConfigLabel else { return }
    withAnimation(.easeOut(duration: 0.35)) { showProfileLabel = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      withAnimation(.easeIn(duration: 0.4)) { showProfileLabel = false }
    }
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

  // MARK: - Top bar (X exit + segmented progress + timer + captions)

  private var topBar: some View {
    VStack(spacing: 10) {
      HStack(spacing: 12) {
        Button {
          narrator.stop()
          onExit()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.textMuted)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Theme.surfaceRaised.opacity(0.7)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close lecture")

        progressBar

        Text(beatTimerLabel)
          .font(.system(size: 12, weight: .bold).monospacedDigit())
          .foregroundStyle(Theme.textMuted)
          .frame(minWidth: 34, alignment: .trailing)

        Button {
          captionsOn.toggle()
        } label: {
          Image(systemName: captionsOn ? "captions.bubble.fill" : "captions.bubble")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(captionsOn ? Theme.accent : Theme.textMuted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle captions")
      }

      HStack {
        Spacer()
        Button {
          narrator.stop()
          onSkipToPractice()
        } label: {
          HStack(spacing: 5) {
            Text("Skip to practice").font(.system(size: 12, weight: .bold))
            Image(systemName: "forward.fill").font(.system(size: 10, weight: .bold))
          }
          .foregroundStyle(Theme.textFaint)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 8)
    .padding(.bottom, 8)
  }

  /// Approximate per-beat time remaining derived from narration progress.
  private var beatTimerLabel: String {
    let remaining = max(0, 1 - narrator.progress)
    let est = 18.0  // nominal beat seconds for a readable countdown
    let secs = Int((remaining * est).rounded())
    return String(format: "0:%02d", secs)
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
    VStack(spacing: 18) {
      beatVisual(beat: beat, mode: mode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      // Signal phrase — the ONLY narration-derived text shown by default.
      if beat.visual != .recallQuestion {
        Text(beat.signalPhrase)
          .font(.system(size: 26, weight: .heavy))
          .multilineTextAlignment(.center)
          .foregroundStyle(Theme.text)
          .shadow(color: Color(hex: 0x0B0910).opacity(0.7), radius: 8, y: 2)
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
      // Beats 1 (hook) + 5 (takeaway): coach TALKING, full face-on, feathered.
      auraStage(big: true)
    case .contrastCards:
      VStack(spacing: 16) {
        auraStage(big: false)
        InsightSignalCard(
          signalPhrase: beat.signalPhrase,
          supporting: insightChips(mode: mode)
        )
        .padding(.horizontal, 18)
      }
    case .spokenLineCards, .chatMockup:
      VStack(spacing: 12) {
        auraStage(big: false)
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

  // MARK: - Aura coach stage (feathered full-bleed for avatar beats, PiP else)

  @ViewBuilder
  private func auraStage(big: Bool) -> some View {
    let speaking = narrator.isSpeaking && !isPaused
    if big {
      AuraCoachStage(coach: coach, speaking: speaking, talkingTake: talkingTake)
        .frame(maxWidth: .infinity)
        .frame(height: 380)
    } else {
      // Small feathered IDLE picture-in-picture.
      AuraCoachStage(coach: coach, speaking: false, talkingTake: talkingTake, compact: true)
        .frame(width: 132, height: 132)
    }
  }

  // MARK: - Recall view (active-recall tap)

  @ViewBuilder
  private func recallView(_ recall: RecallCheck) -> some View {
    VStack(spacing: 16) {
      auraStage(big: false)
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
          .fill(
            answered && (isCorrect || isChosen) ? tone.opacity(0.10) : Theme.surface.opacity(0.7))
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
