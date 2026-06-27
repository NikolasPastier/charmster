import AVFoundation
import SwiftUI

/// Audio-first onboarding lesson player — mirrors LectureStoryPlayerView but
/// scoped to the two onboarding lessons (`onboarding-attachment-style` and
/// `onboarding-flirting-style`).
///
/// Audio is resolved from the `lecture-audio` bucket via
/// `LectureAudioURL.lectureAudioURL(lectureId:coachId:beatId:)`, the same path
/// the main lecture player uses. OS/system TTS is never used: on a missing
/// clip the player tries `"theo"` as a backup, then proceeds silently with
/// captions only.
///
/// Beat order: hook → coreInsight → goodVsBad → recall → takeaway.
/// The recall screen plays two clips in sequence (recallQuestion, then
/// recallWhy after the user picks an answer).
struct OnboardingLessonPlayerView: View {
  let lessonId: String
  let coachId: String
  let onComplete: () -> Void

  @State private var narrator = LectureBeatNarrator()
  @State private var screenIndex: Int = 0
  @State private var recallState: RecallPhase = .questionPlaying
  @State private var recallAnswer: Int? = nil
  @State private var captionsOn: Bool = true
  @State private var preloadedItem: AVPlayerItem?

  private let screens: [LessonScreen]

  init(lessonId: String, coachId: String, onComplete: @escaping () -> Void) {
    self.lessonId = lessonId
    self.coachId = coachId
    self.onComplete = onComplete
    self.screens = OnboardingLessonContent.screens(for: lessonId)
  }

  private enum RecallPhase {
    case questionPlaying, waitingAnswer, whyPlaying, done
  }

  private var currentScreen: LessonScreen? {
    screens.indices.contains(screenIndex) ? screens[screenIndex] : nil
  }

  var body: some View {
    ZStack {
      AuraBackground()
      VStack(spacing: 0) {
        topBar
        if let screen = currentScreen {
          screenContent(screen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { handleTap() }
            .id(screenIndex)
        }
        bottomBar
      }
    }
    .onAppear { startCurrentScreen() }
    .onDisappear { narrator.stop() }
  }

  // MARK: - Top bar

  private var topBar: some View {
    HStack(spacing: 12) {
      Button {
        narrator.stop()
        onComplete()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(Theme.textMuted)
          .frame(width: 30, height: 30)
          .background(Circle().fill(Theme.surfaceRaised.opacity(0.7)))
      }
      .buttonStyle(.plain)

      progressCapsules

      Button { captionsOn.toggle() } label: {
        Image(systemName: captionsOn ? "captions.bubble.fill" : "captions.bubble")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(captionsOn ? Theme.accent : Theme.textMuted)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
    .padding(.bottom, 8)
  }

  private var progressCapsules: some View {
    HStack(spacing: 5) {
      ForEach(screens.indices, id: \.self) { i in
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
    .animation(.linear(duration: 0.2), value: narrator.progress)
    .animation(.easeInOut(duration: 0.25), value: screenIndex)
  }

  private func segmentFill(_ i: Int) -> CGFloat {
    if i < screenIndex { return 1 }
    if i > screenIndex { return 0 }
    // Recall screen: show partial progress across both clips
    if currentScreen?.kind == .recall {
      switch recallState {
      case .questionPlaying: return CGFloat(narrator.progress * 0.5)
      case .waitingAnswer: return 0.5
      case .whyPlaying: return 0.5 + CGFloat(narrator.progress * 0.5)
      case .done: return 1
      }
    }
    return CGFloat(max(0.04, narrator.progress))
  }

  // MARK: - Screen dispatch

  @ViewBuilder
  private func screenContent(_ screen: LessonScreen) -> some View {
    switch screen.kind {
    case .hook:
      teachingCard(screen, kicker: "THE HOOK", showCoach: false)
    case .coreInsight:
      teachingCard(screen, kicker: "THE BIG IDEA", showCoach: true)
    case .goodVsBad:
      contrastCard(screen)
    case .recall:
      recallCard(screen)
    case .takeaway:
      verdictCard(screen)
    }
  }

  // MARK: - Teaching card (Hook / Core Insight)

  private func teachingCard(_ screen: LessonScreen, kicker: String, showCoach: Bool) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: 12)
      if showCoach { coachIcon.padding(.bottom, 16) }
      gradientKicker(kicker).padding(.bottom, 14)
      heroText(screen.signalPhrase)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
      auraRule.padding(.top, 14).padding(.bottom, 20)
      Text(supportLine(screen.narrationText))
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color(hex: 0xF5F0F7).opacity(0.85))
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 20)
      Spacer(minLength: 8)
      subtitleView(for: screen)
    }
  }

  // MARK: - Contrast card (Good vs Bad)

  private func contrastCard(_ screen: LessonScreen) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: 12)
      gradientKicker("IN PRACTICE").padding(.bottom, 18)
      VStack(spacing: 12) {
        if let good = screen.goodLine {
          contrastSlot(label: "✓  WORKS", line: good, tag: screen.goodTag, isGood: true)
        }
        if let bad = screen.badLine {
          contrastSlot(label: "✗  AVOID", line: bad, tag: screen.badTag, isGood: false)
        }
      }
      .padding(.horizontal, 20)
      Spacer(minLength: 8)
      subtitleView(for: screen)
    }
  }

  private func contrastSlot(label: String, line: String, tag: String?, isGood: Bool) -> some View {
    let accent: Color = isGood ? Theme.good : Theme.bad
    return VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .font(.system(size: 13, weight: .heavy)).tracking(0.5)
        .foregroundStyle(accent)
      Text("\"\(line)\"")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Color(hex: 0xF5F0F7))
        .lineLimit(5).fixedSize(horizontal: false, vertical: true)
      if let tag {
        Text(tag)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Color(hex: 0xF5F0F7).opacity(0.72))
          .lineLimit(2)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(accent.opacity(0.07)))
    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(accent.opacity(0.35), lineWidth: 1.5))
  }

  // MARK: - Recall card

  @ViewBuilder
  private func recallCard(_ screen: LessonScreen) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: 12)
      gradientKicker("QUICK CHECK").padding(.bottom, 20)
      VStack(spacing: 16) {
        Text(screen.recallQuestion ?? screen.signalPhrase)
          .font(.system(size: 22, weight: .heavy))
          .multilineTextAlignment(.center)
          .foregroundStyle(Theme.text)
          .padding(.horizontal, 20)

        VStack(spacing: 10) {
          ForEach(screen.recallOptions.indices, id: \.self) { i in
            recallOption(i, screen: screen)
          }
        }
        .padding(.horizontal, 20)

        if recallAnswer != nil {
          VStack(spacing: 6) {
            Text(screen.recallWhy ?? "")
              .font(.system(size: 14))
              .foregroundStyle(Theme.text.opacity(0.85))
              .multilineTextAlignment(.center)
              .padding(.horizontal, 20)
          }
          .transition(.opacity)
        }
      }
      .animation(.easeInOut(duration: 0.25), value: recallAnswer)

      Spacer(minLength: 8)
    }
  }

  @ViewBuilder
  private func recallOption(_ i: Int, screen: LessonScreen) -> some View {
    let answered = recallAnswer != nil
    let isChosen = recallAnswer == i
    let isCorrect = i == screen.recallCorrectIndex
    let canTap = recallState == .waitingAnswer
    let tone: Color = {
      guard answered else { return Theme.border }
      if isCorrect { return Theme.good }
      if isChosen { return Theme.bad }
      return Theme.border
    }()
    Button {
      guard canTap, recallAnswer == nil else { return }
      recallAnswer = i
      recallState = .whyPlaying
      preloadNextScreen()
      playBeat(beatId: "recallWhy", text: screen.recallWhy ?? "", onComplete: {
        recallState = .done
      })
    } label: {
      HStack {
        Text(screen.recallOptions[i])
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Theme.text)
          .multilineTextAlignment(.leading)
        Spacer()
        if answered, isCorrect {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.good)
        } else if answered, isChosen, !isCorrect {
          Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.bad)
        }
      }
      .padding(.horizontal, 16).padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(answered && (isCorrect || isChosen) ? tone.opacity(0.10) : Theme.surface.opacity(0.7))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(tone.opacity(answered ? 0.5 : 1), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(!canTap || answered)
    .opacity(canTap || answered ? 1 : 0.4)
  }

  // MARK: - Verdict card (Takeaway)

  private func verdictCard(_ screen: LessonScreen) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: 12)
      coachIcon.padding(.bottom, 20)
      gradientKicker("YOUR TAKEAWAY").padding(.bottom, 14)
      heroText(screen.signalPhrase)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
      auraRule.padding(.top, 14).padding(.bottom, 20)
      Text(supportLine(screen.narrationText))
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color(hex: 0xF5F0F7).opacity(0.85))
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 20)
      Spacer(minLength: 8)
      subtitleView(for: screen)
    }
  }

  // MARK: - Bottom bar

  private var bottomBar: some View {
    VStack(spacing: 10) {
      if isLastScreen {
        AuraButton(title: "Got it", systemImage: "checkmark") {
          narrator.stop()
          onComplete()
        }
      } else if currentScreen?.kind == .recall {
        AuraButton(
          title: recallState == .done ? "Continue" : (recallAnswer == nil ? "Pick one to continue" : "…"),
          systemImage: "arrow.right",
          enabled: recallState == .done
        ) { advance() }
      } else {
        HStack {
          Button { goBack() } label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(Theme.textMuted)
              .opacity(screenIndex == 0 ? 0.3 : 1)
          }
          .buttonStyle(.plain)
          .disabled(screenIndex == 0)
          Spacer()
          Text("Tap to continue")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text.opacity(0.7))
          Spacer()
          Button { advance() } label: {
            Image(systemName: "chevron.right")
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(Theme.textMuted)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
    .padding(.bottom, 18)
  }

  private var isLastScreen: Bool { screenIndex >= screens.count - 1 }

  // MARK: - Navigation

  private func handleTap() {
    guard currentScreen?.kind != .recall else { return }
    if !isLastScreen { advance() }
  }

  private func advance() {
    guard !isLastScreen else { narrator.stop(); onComplete(); return }
    narrator.stop()
    withAnimation(.easeInOut(duration: 0.3)) { screenIndex += 1 }
    recallAnswer = nil
    recallState = .questionPlaying
    startCurrentScreen()
  }

  private func goBack() {
    guard screenIndex > 0 else { return }
    narrator.stop()
    withAnimation(.easeInOut(duration: 0.3)) { screenIndex -= 1 }
    recallAnswer = nil
    recallState = .questionPlaying
    startCurrentScreen()
  }

  // MARK: - Playback

  private func startCurrentScreen() {
    guard let screen = currentScreen else { return }
    if screen.kind == .recall {
      recallState = .questionPlaying
      playBeat(beatId: "recallQuestion", text: screen.narrationText, onComplete: {
        recallState = .waitingAnswer
      })
    } else {
      playBeat(beatId: screen.beatId, text: screen.narrationText, onComplete: {
        // Auto-advance non-interactive screens when audio finishes
        guard screen.kind != .takeaway else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { advance() }
      })
    }
    preloadNextScreen()
  }

  /// Play a beat via the narrator, trying the backup coach on failure.
  private func playBeat(beatId: String, text: String, onComplete: @escaping () -> Void) {
    let primary = coachId
    let backup = "theo"
    narrator.speakBeat(
      lessonId: lessonId, beatId: beatId, text: text,
      coachId: primary, coachStyle: CoachPersona.resolve(id: primary).style,
      onMissing: {
        guard primary != backup else {
          // Both failed — advance silently after a short pause so captions remain visible.
          DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { onComplete() }
          return
        }
        narrator.speakBeat(
          lessonId: lessonId, beatId: beatId, text: text,
          coachId: backup, coachStyle: CoachPersona.resolve(id: backup).style,
          onMissing: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { onComplete() }
          },
          onComplete: onComplete
        )
      },
      onComplete: onComplete
    )
  }

  /// Prime the OS network cache for the next screen's audio so it buffers
  /// while the current clip plays. The preloaded AVPlayerItem is kept alive
  /// in @State; when LectureBeatNarrator requests the same URL, iOS returns
  /// it from the in-memory asset cache.
  private func preloadNextScreen() {
    let next = screenIndex + 1
    guard next < screens.count,
      let url = LectureAudioURL.lectureAudioURL(
        lectureId: lessonId, coachId: coachId, beatId: screens[next].beatId)
    else { return }
    preloadedItem = AVPlayerItem(url: url)
  }

  // MARK: - Shared atoms

  private var coachIcon: some View {
    let persona = CoachPersona.resolve(id: coachId)
    return CoachAvatarView(coach: persona, baseState: .idle)
      .frame(width: 64, height: 64)
      .clipShape(Circle())
      .overlay(Circle().stroke(Theme.auraGradient, lineWidth: 2.5))
  }

  private func gradientKicker(_ label: String) -> some View {
    Text(label)
      .font(.system(size: 12, weight: .heavy)).tracking(3)
      .foregroundStyle(Theme.auraGradient)
  }

  private func heroText(_ phrase: String) -> some View {
    let words = phrase.split(separator: " ").map(String.init)
    let cutoff = max(0, words.count - 2)
    let plain = cutoff > 0 ? words.prefix(cutoff).joined(separator: " ") + " " : ""
    let grad = words.suffix(2).joined(separator: " ")
    return Group {
      if plain.isEmpty {
        Text(phrase)
          .font(.system(size: 33, weight: .heavy))
          .foregroundStyle(Theme.auraGradient)
      } else {
        (Text(plain).foregroundStyle(Color(hex: 0xF5F0F7))
          + Text(grad).foregroundStyle(Theme.auraGradient))
          .font(.system(size: 33, weight: .heavy))
      }
    }
  }

  private var auraRule: some View {
    RoundedRectangle(cornerRadius: 2).fill(Theme.auraGradient).frame(width: 44, height: 3)
  }

  private func supportLine(_ text: String) -> String {
    let first = text.components(separatedBy: ". ").first ?? text
    let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
    let words = trimmed.split(separator: " ")
    if words.count <= 18 {
      return (trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!"))
        ? trimmed : "\(trimmed)."
    }
    return words.prefix(18).joined(separator: " ") + "…"
  }

  // MARK: - Captions

  @ViewBuilder
  private func subtitleView(for screen: LessonScreen) -> some View {
    if captionsOn {
      let chunks = subtitleChunks(screen.narrationText)
      let idx = max(0, min(chunks.count - 1, Int(narrator.progress * Double(chunks.count))))
      let text = chunks.isEmpty ? "" : chunks[idx]
      if !text.isEmpty {
        Text(text)
          .font(.system(size: 15))
          .foregroundStyle(.white.opacity(0.85))
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .padding(.horizontal, 18).padding(.vertical, 9)
          .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.38)))
          .padding(.horizontal, 20)
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
}

// MARK: - Lesson screen data

struct LessonScreen: Identifiable {
  enum Kind { case hook, coreInsight, goodVsBad, recall, takeaway }
  let id: String
  let kind: Kind
  let beatId: String
  let narrationText: String
  let signalPhrase: String
  var goodLine: String? = nil
  var goodTag: String? = nil
  var badLine: String? = nil
  var badTag: String? = nil
  var recallQuestion: String? = nil
  var recallOptions: [String] = []
  var recallCorrectIndex: Int = 0
  var recallWhy: String? = nil
}

// MARK: - Static lesson content

enum OnboardingLessonContent {
  static func screens(for lessonId: String) -> [LessonScreen] {
    switch lessonId {
    case "onboarding-attachment-style": return attachmentScreens
    case "onboarding-flirting-style": return flirtingScreens
    default: return []
    }
  }

  // MARK: Attachment Style

  private static let attachmentScreens: [LessonScreen] = [
    LessonScreen(
      id: "att.hook", kind: .hook, beatId: "hook",
      narrationText:
        "Your attachment style is the invisible script running underneath every text, every date, every silence. Understanding it is the first step to rewriting it.",
      signalPhrase: "The invisible script"
    ),
    LessonScreen(
      id: "att.insight", kind: .coreInsight, beatId: "coreInsight",
      narrationText:
        "Attachment isn't fixed — it's a pattern your nervous system learned. Secure attachment means trusting a connection without needing constant proof it's working.",
      signalPhrase: "Trust without proof"
    ),
    LessonScreen(
      id: "att.gvb", kind: .goodVsBad, beatId: "goodVsBad",
      narrationText:
        "Here's how secure and anxious attachment show up in the exact same moment.",
      signalPhrase: "Same moment, different response",
      goodLine: "They haven't replied in two hours. They're probably busy — I'll give it space.",
      goodTag: "Secure: trust the connection",
      badLine: "They haven't replied in two hours — I need to check in right now.",
      badTag: "Anxious: needs constant reassurance"
    ),
    LessonScreen(
      id: "att.recall", kind: .recall, beatId: "recallQuestion",
      narrationText:
        "Which response shows secure attachment when someone takes a while to reply?",
      signalPhrase: "Check your read",
      recallQuestion: "Someone you like takes two hours to reply. What's the secure response?",
      recallOptions: [
        "Send a follow-up to check if they're still interested",
        "Assume they're pulling away and match their distance",
        "Trust the connection and give it space",
        "Double-text to stay on their mind",
      ],
      recallCorrectIndex: 2,
      recallWhy:
        "Secure attachment means trusting the connection without needing constant reassurance. You give people space without it triggering anxiety."
    ),
    LessonScreen(
      id: "att.takeaway", kind: .takeaway, beatId: "takeawayHandoff",
      narrationText:
        "Your attachment style is a starting point, not a life sentence. Every rep here builds toward secure — one interaction at a time.",
      signalPhrase: "Every rep counts"
    ),
  ]

  // MARK: Flirting Style

  private static let flirtingScreens: [LessonScreen] = [
    LessonScreen(
      id: "flt.hook", kind: .hook, beatId: "hook",
      narrationText:
        "There's no single right way to flirt. But there's a way that feels natural to you — and four proven styles to build from.",
      signalPhrase: "Four styles, one that fits"
    ),
    LessonScreen(
      id: "flt.insight", kind: .coreInsight, beatId: "coreInsight",
      narrationText:
        "Warm builds emotional safety. Playful creates fun tension. Dry uses wit and contrast. Direct states interest clearly. All four work — calibration is what makes the difference.",
      signalPhrase: "Calibrate to the moment"
    ),
    LessonScreen(
      id: "flt.gvb", kind: .goodVsBad, beatId: "goodVsBad",
      narrationText: "Here's calibrated versus uncalibrated flirting in the same setting.",
      signalPhrase: "Calibration wins",
      goodLine: "That book looks better than mine — what's it about?",
      goodTag: "Curious, playful — opens conversation",
      badLine: "I think you're really attractive.",
      badTag: "Direct without calibration — low impact"
    ),
    LessonScreen(
      id: "flt.recall", kind: .recall, beatId: "recallQuestion",
      narrationText: "What separates effective flirting from flat flirting?",
      signalPhrase: "What actually works",
      recallQuestion: "What makes a flirting style effective, regardless of which one you use?",
      recallOptions: [
        "Being as bold and confident as possible",
        "Calibrating to the person and the moment",
        "Always leading with humor",
        "Stating your interest directly right away",
      ],
      recallCorrectIndex: 1,
      recallWhy:
        "The best style isn't the most confident — it's the one that reads the room. Calibration turns any style into a real connection."
    ),
    LessonScreen(
      id: "flt.takeaway", kind: .takeaway, beatId: "takeawayHandoff",
      narrationText:
        "Your style will emerge through practice. We'll help you get comfortable leading with it and adapting on the fly.",
      signalPhrase: "Lead and adapt"
    ),
  ]
}
