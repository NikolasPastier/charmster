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
  @State private var captionsOn: Bool = true
  @State private var isPaused: Bool = false
  @State private var showProfileLabel: Bool = false
  /// UX5 — the lecture opens on Card 0 ("What you'll learn"), a silent prelude
  /// shown before Beat 1. It's skippable like any card; advancing starts the
  /// audio Hook. Going back from Beat 1 returns here.
  @State private var inPrelude: Bool = true

  /// Talking take chosen ONCE per lecture, held for the whole session.
  @State private var talkingTake: Int = 1

  // Recall beat state
  @State private var recallChoice: Int?

  /// Single horizontal margin token used by every beat, top bar, and bottom bar.
  private let hMargin: CGFloat = 20

  private var coach: CoachPersona { coachOverride ?? app.selectedCoach }

  var body: some View {
    Group {
      ZStack {
        if let story {
          content(story: story)
        } else {
          ProgressView().tint(Theme.accent)
        }
        if showProfileLabel {
          profileMicroLabel
        }
      }
      .background { AuraBackground() }
      .onAppear {
        talkingTake = CoachClipCatalog.shared.randomTalkingTake()
        Task { await CoachClipCatalog.shared.preload(persona: coach, talkingTake: talkingTake) }
        CoachExpressionStore.shared.prefetch(coachId: coach.id)
        buildStoryIfNeeded()
        // UX5 — start on the silent Card 0; audio Hook begins when the user
        // advances past the prelude.
        showProfileMicroLabelIfNeeded()
      }
      .onDisappear { narrator.stop() }
    }
    .trackView("LectureStoryPlayerView")
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
        if inPrelude {
          LectureObjectivesCard(
            objectives: story.learningObjectives,
            replayToken: "\(story.id)#prelude"
          )
          .transition(.opacity)
        } else {
          ForEach(Array(beats.enumerated()), id: \.element.id) { i, beat in
            if i == index {
              beatCard(beat: beat, mode: story.conversationMode)
                .transition(.opacity)
            }
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
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
          .opacity(inPrelude ? 0 : 1)

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
            Text("Skip to practice")
              .font(.system(size: 12, weight: .bold))
              .lineLimit(1)
            Image(systemName: "forward.fill").font(.system(size: 10, weight: .bold))
          }
          .foregroundStyle(Theme.text.opacity(0.65))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, hMargin)
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
      // UX5 — a distinct, smaller "prelude" segment for Card 0.
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Theme.surfaceRaised)
          Capsule()
            .fill(Theme.auraGradient)
            .frame(width: geo.size.width * (inPrelude ? 0.5 : 1))
        }
      }
      .frame(width: 16, height: 4)

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
    .animation(.easeInOut(duration: 0.25), value: inPrelude)
    .animation(.linear(duration: 0.2), value: narrator.progress)
  }

  private func segmentFill(_ i: Int) -> CGFloat {
    if inPrelude { return 0 }
    if i < index { return 1 }
    if i > index { return 0 }
    return CGFloat(max(0.04, narrator.progress))
  }

  // MARK: - Beat card

  @ViewBuilder
  private func beatCard(beat: LectureBeat, mode: ConversationMode) -> some View {
    VStack(spacing: 0) {
      beatHeader(beat: beat)
      beatVisual(beat: beat, mode: mode)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      subtitleView(for: beat)
    }
    .padding(.bottom, 10)
  }

  @ViewBuilder
  private func beatVisual(beat: LectureBeat, mode: ConversationMode) -> some View {
    switch beat.visual {
    case .avatar:
      // Hook (Beat 1) + Takeaway (Beat 5): coach talking loop, full-bleed, feathered.
      auraStage(big: true, expression: ExpressionPose.pose(for: beat.kind))
    case .contrastCards:
      // Core Insight: teaching visual in the media zone. Headline shown at top.
      CoreInsightVisualCard(
        lecture: lecture,
        headline: beat.signalPhrase,
        caption: insightChips(mode: mode).joined(separator: " · "),
        showHeadline: false
      )
      .padding(.horizontal, hMargin)
    case .spokenLineCards, .chatMockup:
      // GOOD vs BAD: two side-by-side cards. Voiceover narrates — NO coach.
      if let good = beat.goodExample, let bad = beat.badExample {
        GoodBadContrastFrame(mode: mode, good: good, bad: bad)
          .padding(.horizontal, hMargin)
      }
    case .recallQuestion:
      // RECALL: question + tappable options. Voice only — NO coach.
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
  private func auraStage(big: Bool, expression: ExpressionPose = .neutral) -> some View {
    let speaking = narrator.isSpeaking && !isPaused
    if big {
      AuraCoachStage(
        coach: coach, speaking: speaking, talkingTake: talkingTake, expression: expression
      )
      .frame(maxWidth: .infinity)
      .frame(height: 340)
    } else {
      // Small feathered IDLE picture-in-picture.
      AuraCoachStage(
        coach: coach, speaking: false, talkingTake: talkingTake, compact: true, expression: expression
      )
      .frame(width: 132, height: 132)
    }
  }

  // MARK: - Recall view (active-recall tap)

  @ViewBuilder
  private func recallView(_ recall: RecallCheck) -> some View {
    let opts = shuffledOptions(for: recall)
    let correctText = recall.correctIndex < recall.options.count
      ? recall.options[recall.correctIndex] : ""
    VStack(spacing: 16) {
      Text(recall.question)
        .font(.system(size: 22, weight: .heavy))
        .multilineTextAlignment(.center)
        .foregroundStyle(Theme.text)
        .padding(.horizontal, hMargin)

      VStack(spacing: 10) {
        ForEach(opts.indices, id: \.self) { i in
          recallOption(recall, i, opts: opts, correctText: correctText)
        }
      }
      .padding(.horizontal, hMargin)

      if let choice = recallChoice {
        let correct = choice < opts.count && opts[choice] == correctText
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
            .padding(.horizontal, hMargin)
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
  private func recallOption(
    _ recall: RecallCheck, _ i: Int, opts: [String], correctText: String
  ) -> some View {
    let answered = recallChoice != nil
    let isChosen = recallChoice == i
    let isCorrect = opts[i] == correctText
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
      if let beat = currentBeat {
        narrator.speakRecallWhy(beat, coach: coach, lecture: lecture) {}
      }
    } label: {
      HStack {
        Text(opts[i])
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
      if inPrelude {
        AuraButton(title: "Start lecture", systemImage: "play.fill") {
          advanceFromTap()
        }
      } else if isLast {
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
              .foregroundStyle(Theme.textMuted)
              .opacity(index == 0 ? 0.3 : 1.0)
          }
          .buttonStyle(.plain)
          .disabled(index == 0)
          Spacer()
          Text("Tap to continue")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text.opacity(0.7))
          Spacer()
          Button {
            advanceFromTap()
          } label: {
            Image(systemName: "chevron.right")
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(Theme.textMuted)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.horizontal, hMargin)
    .padding(.top, 8)
    .padding(.bottom, 18)
  }

  // MARK: - Playback control

  private func startBeat() {
    guard let beat = currentBeat else { return }
    isPaused = false
    narrator.speak(beat, coach: coach, lecture: lecture) {
      // Auto-advance after audio ends — except the recall beat, which waits
      // for a tap so the user actually answers.
      if beat.kind == .recallCheck { return }
      if !isLast { advance() }
    }
  }

  private func advanceFromTap() {
    // UX5 — leaving Card 0 starts the audio Hook.
    if inPrelude {
      withAnimation(.easeInOut(duration: 0.3)) { inPrelude = false }
      startBeat()
      return
    }
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
    // UX5 — from Beat 1, going back returns to the silent Card 0.
    if !inPrelude, index == 0 {
      narrator.stop()
      withAnimation(.easeInOut(duration: 0.3)) { inPrelude = true }
      return
    }
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

  // MARK: - Quiet beat header (LX10.3)

  private func beatHeader(beat: LectureBeat) -> some View {
    VStack(spacing: 2) {
      Text(lecture.title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color(hex: 0xF5F0F7))
        .lineLimit(1)
        .truncationMode(.tail)
      Text(beatLabel(for: beat.kind))
        .font(.system(size: 11))
        .foregroundStyle(Color(hex: 0xF5F0F7).opacity(0.55))
    }
    .padding(.top, 4)
    .padding(.bottom, 6)
  }

  private func beatLabel(for kind: LectureBeatKind) -> String {
    switch kind {
    case .hook:            return "Hook"
    case .coreInsight:     return "Core insight"
    case .goodVsBad:       return "Good vs bad"
    case .recallCheck:     return "Your call"
    case .takeawayHandoff: return "Takeaway"
    }
  }

  // MARK: - Bottom subtitles (LX10.4)

  @ViewBuilder
  private func subtitleView(for beat: LectureBeat) -> some View {
    if captionsOn {
      let chunks = subtitleChunks(beat.narrationText)
      let idx = max(0, min(chunks.count - 1, Int(narrator.progress * Double(chunks.count))))
      let text = chunks.isEmpty ? "" : chunks[idx]
      if !text.isEmpty {
        Text(text)
          .font(.system(size: 15))
          .foregroundStyle(.white.opacity(0.85))
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .padding(.horizontal, 18)
          .padding(.vertical, 9)
          .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.38)))
          .padding(.horizontal, hMargin)
          .padding(.top, 8)
          .animation(.easeInOut(duration: 0.18), value: idx)
      }
    }
  }

  private func subtitleChunks(_ text: String) -> [String] {
    var chunks: [String] = []
    var current = ""
    for sentence in text.components(separatedBy: ". ") {
      let s = sentence.trimmingCharacters(in: .whitespaces)
      guard !s.isEmpty else { continue }
      let candidate = current.isEmpty ? s : "\(current). \(s)"
      if candidate.split(separator: " ").count > 12 && !current.isEmpty {
        chunks.append("\(current).")
        current = s
      } else {
        current = candidate
      }
    }
    if !current.isEmpty {
      let end = current.hasSuffix(".") || current.hasSuffix("?") || current.hasSuffix("!")
      chunks.append(end ? current : "\(current).")
    }
    return chunks.isEmpty ? [text] : chunks
  }

  // MARK: - Seeded recall shuffle (LX10.1)

  private func shuffledOptions(for recall: RecallCheck) -> [String] {
    var opts = recall.options
    var rng = SeededRNG(seed: stableHash(lecture.id))
    opts.shuffle(using: &rng)
    return opts
  }

  private func stableHash(_ s: String) -> UInt64 {
    var h: UInt64 = 5381
    for byte in s.utf8 { h = (h &<< 5) &+ h &+ UInt64(byte) }
    return h == 0 ? 1 : h
  }

  private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
      state ^= state << 13
      state ^= state >> 7
      state ^= state << 17
      return state
    }
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
