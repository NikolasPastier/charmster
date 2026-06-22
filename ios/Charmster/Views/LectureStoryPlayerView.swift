import SwiftUI

/// Type-led lecture card player — redesigned to the approved Aura mockups.
///
/// Six-card flow: Intro (coach icon + objectives) → Hook → Core Insight →
/// Works vs Avoid → Quick Check (quiz) → Verdict (coach icon + takeaway).
/// Teaching cards are pure typography over the Aura gradient; coach clips are
/// NOT shown mid-lecture — only a small circular coach icon on Intro + Verdict.
/// Narration plays as audio; subtitles advance from narrator.progress.
/// Quiz logic, scoring, and audio are UNCHANGED — presentation only.
struct LectureStoryPlayerView: View {
  @Environment(AppState.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  let lecture: Lecture
  var coachOverride: CoachPersona? = nil
  var showAutoConfigLabel: Bool = false
  let onPractice: () -> Void
  let onSkipToPractice: () -> Void
  var onExit: () -> Void = {}

  @State private var story: LectureStory?
  @State private var index: Int = 0
  @State private var narrator = LectureBeatNarrator()
  @State private var captionsOn: Bool = true
  @State private var isPaused: Bool = false
  @State private var showProfileLabel: Bool = false
  @State private var inPrelude: Bool = true
  @State private var talkingTake: Int = 1
  @State private var recallChoice: Int?

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
        if showProfileLabel { profileMicroLabel }
      }
      .background { AuraBackground() }
      .onAppear {
        talkingTake = CoachClipCatalog.shared.randomTalkingTake()
        Task { await CoachClipCatalog.shared.preload(persona: coach, talkingTake: talkingTake) }
        CoachExpressionStore.shared.prefetch(coachId: coach.id)
        buildStoryIfNeeded()
        showProfileMicroLabelIfNeeded()
      }
      .onDisappear { narrator.stop() }
    }
    .trackView("LectureStoryPlayerView")
  }

  // MARK: - Profile micro-label

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
          introCard(story: story)
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
            if value.translation.width < -40 { advanceFromTap() }
            else if value.translation.width > 40 { goBack() }
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

  // MARK: - Top bar

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

      if !inPrelude {
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
    }
    .padding(.horizontal, hMargin)
    .padding(.top, 8)
    .padding(.bottom, 8)
  }

  // MARK: - Progress bar

  private var progressBar: some View {
    HStack(spacing: 5) {
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

  // MARK: - Card 1 · Intro (prelude)

  @ViewBuilder
  private func introCard(story: LectureStory) -> some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 0) {
        Spacer(minLength: 24).frame(height: 24)

        coachIcon(size: 84)
          .padding(.bottom, 20)

        gradientKicker("WITH \(coach.humanName.uppercased()) · \(coach.roleTag.uppercased())")
          .padding(.bottom, 16)

        Text(lecture.title)
          .font(.system(size: 30, weight: .heavy))
          .foregroundStyle(Color(hex: 0xF5F0F7))
          .multilineTextAlignment(.center)
          .lineLimit(3)
          .padding(.horizontal, hMargin)

        auraRule
          .padding(.top, 14)
          .padding(.bottom, 24)

        VStack(alignment: .leading, spacing: 14) {
          Text("BY THE END YOU'LL")
            .font(.system(size: 11, weight: .heavy))
            .tracking(2.5)
            .foregroundStyle(Color(hex: 0xF5F0F7).opacity(0.45))
            .frame(maxWidth: .infinity, alignment: .leading)

          ForEach(Array(story.learningObjectives.prefix(3).enumerated()), id: \.offset) { _, obj in
            HStack(alignment: .top, spacing: 10) {
              Text("·")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.pink)
                .frame(width: 12, alignment: .center)
              Text(obj)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: 0xF5F0F7))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        .padding(.horizontal, hMargin)
        .frame(maxWidth: .infinity, alignment: .leading)

        Spacer(minLength: 24).frame(height: 24)
      }
      .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Beat card (dispatch by kind)

  @ViewBuilder
  private func beatCard(beat: LectureBeat, mode: ConversationMode) -> some View {
    VStack(spacing: 0) {
      beatHeader(beat: beat)
      switch beat.kind {
      case .hook:
        teachingCard(beat: beat, kicker: "THE HOOK", showCoachChip: false)
      case .coreInsight:
        teachingCard(beat: beat, kicker: "THE BIG IDEA", showCoachChip: true)
      case .goodVsBad:
        worksAvoidCard(beat: beat)
      case .recallCheck:
        quizCard(beat: beat)
      case .takeawayHandoff:
        verdictCard(beat: beat)
      }
    }
    .padding(.bottom, 10)
  }

  // MARK: - Card 2 & 3 · Teaching card (Hook + Core Insight)

  @ViewBuilder
  private func teachingCard(beat: LectureBeat, kicker: String, showCoachChip: Bool) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: 12)

      if showCoachChip {
        coachIcon(size: 64)
          .padding(.bottom, 16)
      }

      gradientKicker(kicker)
        .padding(.bottom, 14)

      heroText(phrase: beat.signalPhrase)
        .multilineTextAlignment(.center)
        .lineSpacing(2)
        .lineLimit(4)
        .padding(.horizontal, hMargin)

      auraRule
        .padding(.top, 14)
        .padding(.bottom, 20)

      Text(supportLine(beat.narrationText))
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color(hex: 0xF5F0F7).opacity(0.58))
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, hMargin)

      Spacer(minLength: 8)

      subtitleView(for: beat)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Card 4 · Works vs Avoid

  @ViewBuilder
  private func worksAvoidCard(beat: LectureBeat) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: 12)

      gradientKicker("IN PRACTICE")
        .padding(.bottom, 18)

      VStack(spacing: 12) {
        if let good = beat.goodExample {
          contrastCard(label: "✓  WORKS", line: good.line, tag: good.reactionTag, isGood: true)
        }
        if let bad = beat.badExample {
          contrastCard(label: "✗  AVOID", line: bad.line, tag: bad.reactionTag, isGood: false)
        }
      }
      .padding(.horizontal, hMargin)

      Spacer(minLength: 8)

      subtitleView(for: beat)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private func contrastCard(label: String, line: String, tag: String?, isGood: Bool) -> some View {
    let accent: Color = isGood ? Theme.good : Theme.bad
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .font(.system(size: 13, weight: .heavy))
        .tracking(0.5)
        .foregroundStyle(accent)
      Text("\"\(line)\"")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Color(hex: 0xF5F0F7))
        .lineLimit(5)
        .fixedSize(horizontal: false, vertical: true)
      if let tag {
        Text(tag)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Color(hex: 0xF5F0F7).opacity(0.48))
          .lineLimit(2)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(accent.opacity(0.07))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(accent.opacity(0.35), lineWidth: 1.5)
    )
  }

  // MARK: - Card 5 · Quiz (recall — logic unchanged, kicker added)

  @ViewBuilder
  private func quizCard(beat: LectureBeat) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: 12)

      gradientKicker("QUICK CHECK")
        .padding(.bottom, 20)

      if let recall = beat.recall {
        recallView(recall)
      }

      Spacer(minLength: 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Card 6 · Verdict (Takeaway)

  @ViewBuilder
  private func verdictCard(beat: LectureBeat) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: 12)

      coachIcon(size: 84)
        .padding(.bottom, 20)

      gradientKicker("YOUR TAKEAWAY")
        .padding(.bottom, 14)

      heroText(phrase: beat.signalPhrase)
        .multilineTextAlignment(.center)
        .lineSpacing(2)
        .lineLimit(4)
        .padding(.horizontal, hMargin)

      auraRule
        .padding(.top, 14)
        .padding(.bottom, 20)

      Text(supportLine(beat.narrationText))
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color(hex: 0xF5F0F7).opacity(0.58))
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, hMargin)

      Spacer(minLength: 8)

      subtitleView(for: beat)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Shared card atoms

  private func gradientKicker(_ label: String) -> some View {
    Text(label)
      .font(.system(size: 12, weight: .heavy))
      .tracking(3)
      .foregroundStyle(Theme.auraGradient)
  }

  private func heroText(phrase: String) -> Text {
    let (plain, grad) = splitHero(phrase)
    if plain.isEmpty {
      return Text(phrase)
        .font(.system(size: 33, weight: .heavy))
        .foregroundStyle(Theme.auraGradient)
    }
    return (
      Text(plain)
        .font(.system(size: 33, weight: .heavy))
        .foregroundStyle(Color(hex: 0xF5F0F7))
      + Text(grad)
        .font(.system(size: 33, weight: .heavy))
        .foregroundStyle(Theme.auraGradient)
    )
  }

  private var auraRule: some View {
    RoundedRectangle(cornerRadius: 2)
      .fill(Theme.auraGradient)
      .frame(width: 44, height: 3)
  }

  private func coachIcon(size: CGFloat) -> some View {
    CoachAvatarView(coach: coach, baseState: .idle)
      .frame(width: size, height: size)
      .clipShape(Circle())
      .overlay(Circle().stroke(Theme.auraGradient, lineWidth: 2.5))
  }

  // MARK: - Beat header (lecture title + beat label, shown on all beats)

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
    case .goodVsBad:       return "Works vs Avoid"
    case .recallCheck:     return "Quick check"
    case .takeawayHandoff: return "Takeaway"
    }
  }

  // MARK: - Subtitles (LX10.4)

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

  // MARK: - Recall view (UNCHANGED LOGIC)

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
            answered && (isCorrect || isChosen)
              ? tone.opacity(0.10) : Theme.surface.opacity(0.7))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(tone.opacity(answered ? 0.5 : 1), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(answered)
  }

  // MARK: - Bottom bar

  @ViewBuilder
  private func bottomBar(beat: LectureBeat?) -> some View {
    VStack(spacing: 10) {
      if inPrelude {
        AuraButton(title: "Begin", systemImage: "play.fill") {
          advanceFromTap()
        }
      } else if isLast {
        VStack(spacing: 8) {
          AuraButton(title: "Start practice", systemImage: "waveform") {
            narrator.stop()
            onPractice()
          }
          Text("\(coach.humanName) will run the scenario with you")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(hex: 0xF5F0F7).opacity(0.42))
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
          Button { goBack() } label: {
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
          Button { advanceFromTap() } label: {
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

  // MARK: - Playback control (UNCHANGED)

  private func startBeat() {
    guard let beat = currentBeat else { return }
    isPaused = false
    narrator.speak(beat, coach: coach, lecture: lecture) {
      if beat.kind == .recallCheck { return }
      if !isLast { advance() }
    }
  }

  private func advanceFromTap() {
    if inPrelude {
      withAnimation(.easeInOut(duration: 0.3)) { inPrelude = false }
      startBeat()
      return
    }
    if currentBeat?.kind == .recallCheck, recallChoice == nil { return }
    if isLast { narrator.stop(); onPractice(); return }
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

  // MARK: - Hero text split

  private func splitHero(_ phrase: String) -> (prefix: String, gradient: String) {
    // Find the last ". " or ", " — the clause after it becomes the gradient punch phrase.
    // Only use the split if the gradient part is ≤ 5 words (a real emphasis fragment).
    for sep in [". ", ", "] {
      if let range = phrase.range(of: sep, options: .backwards) {
        let after = String(phrase[range.upperBound...])
        let wordCount = after.split(separator: " ").count
        if wordCount >= 1 && wordCount <= 5 {
          let before = String(phrase[..<range.upperBound])
          return (before, after)
        }
      }
    }
    // Fallback: last 2 words in gradient
    let words = phrase.split(separator: " ").map(String.init)
    guard words.count > 2 else { return ("", phrase) }
    return (words.dropLast(2).joined(separator: " ") + " ", words.suffix(2).joined(separator: " "))
  }

  // MARK: - Support line

  private func supportLine(_ narration: String) -> String {
    let first = narration.components(separatedBy: ". ").first ?? narration
    let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
    let words = trimmed.split(separator: " ")
    if words.count <= 18 {
      return (trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!"))
        ? trimmed : "\(trimmed)."
    }
    return words.prefix(18).joined(separator: " ") + "…"
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
      state ^= state << 13; state ^= state >> 7; state ^= state << 17
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
