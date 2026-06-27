import SwiftUI

/// Live practice screen — neutral conversation feel, no phone-call chrome.
/// Camera + mic stay ON to power the review. Behind the UI: an AuraGlowLayer
/// bound to the live atmosphere score, and a photoreal video-clip AvatarView
/// driven by who is speaking + the per-turn mood tag streamed from the
/// Realtime model.
struct LivePracticeView: View {
  @Environment(AppState.self) private var app
  let lecture: Lecture?
  let config: SessionConfig
  let onFinish: (SessionResult) -> Void
  let onClose: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var pipeline = LiveSessionPipeline()
  @State private var elapsed: Int = 0
  @State private var showSelfView: Bool = true
  @State private var winddown: Bool = false
  @State private var ended: Bool = false
  @State private var scoring: Bool = false
  @State private var dailyCapHit: Bool = false
  @State private var pendingReaction: AvatarState?
  @State private var lastReactionTag: AvatarState?
  /// UX4 — coach nudge state. Coordinator owns rate-limiting + auto-hide.
  @State private var nudges = CoachNudgeCoordinator()
  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  /// Captions visibility comes from `profile.captionsEnabled` (Settings).
  private var showCaptions: Bool { app.profile.captionsEnabled }

  private var avatarPersona: AvatarPersona { AvatarPersona.resolve(from: config.persona.id) }

  /// UX4 — the coach character whose voice the nudges speak in. The session's
  /// `config.coach` is a tone style; resolve it to the matching named persona.
  private var nudgeCoach: CoachPersona { CoachPersona.forStyle(config.coach) }

  private var practiceLimitSeconds: Int {
    let base: Int
    if let lec = lecture {
      base = lec.isCapstone ? max(480, lec.minutes * 60) : lec.minutes * 60
    } else {
      base = 7 * 60
    }
    return min(max(base, 150), lecture?.isCapstone == true ? 600 : 600)
  }

  private var remaining: Int { max(0, practiceLimitSeconds - elapsed) }

  // MARK: - Avatar driving inputs

  private var avatarBaseState: AvatarState {
    if pipeline.partnerSpeaking { return .talking }
    if pipeline.awaitingAvatarOpen { return .thinking }
    if pipeline.userSpeaking { return .listening }
    if let tag = pipeline.lastMoodTag, tag.isLooping { return tag }
    return .idle
  }

  var body: some View {
    Group {
      ZStack {
        AuraGlowLayer(
          intensity: pipeline.liveFeel,
          partnerSpeaking: pipeline.partnerSpeaking)
        AvatarView(
          persona: avatarPersona,
          baseState: avatarBaseState,
          reaction: pendingReaction,
          onReactionFinished: { pendingReaction = nil }
        )
        .ignoresSafeArea()

        // Soft top/bottom vignette so overlay UI stays legible.
        LinearGradient(
          colors: [
            .black.opacity(0.45), .clear,
            .clear, .black.opacity(0.55),
          ],
          startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)

        if dailyCapHit { dailyCapOverlay } else { mainOverlay }
        if winddown && !dailyCapHit { winddownOverlay }
        if scoring { scoringOverlay }
      }
      .task { await openSession() }
      .onAppear { nudges.configure(level: app.profile.nudgeLevel) }
      .onReceive(timer) { _ in tickFrame() }
      .onChange(of: pipeline.userTurnCount) { _, _ in maybeNudge() }
      .onChange(of: pipeline.lastMoodTag) { _, tag in
        guard let tag, !tag.isLooping, tag != lastReactionTag else { return }
        lastReactionTag = tag
        pendingReaction = tag
      }
      .onDisappear { pipeline.stop() }
    }
    .trackView("LivePracticeView")
  }

  // MARK: - Main overlay

  private var mainOverlay: some View {
    VStack {
      topBar
      Spacer()
      if showCaptions, !pipeline.captionsBuffer.isEmpty {
        Text(pipeline.captionsBuffer)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Theme.text)
          .lineLimit(3)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 16).padding(.vertical, 10)
          .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(.ultraThinMaterial)
          )
          .padding(.horizontal, 22)
      }
      if let nudge = nudges.current {
        CoachNudgeBar(nudge: nudge, coach: nudgeCoach, coordinator: nudges)
          .padding(.bottom, 4)
      }
      bottomBar
    }
    .animation(
      reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.85),
      value: nudges.current?.id)
  }

  // MARK: - Top bar (minimal)

  private var topBar: some View {
    HStack {
      Button(action: endNow) {
        Image(systemName: "xmark")
          .font(.system(size: 14, weight: .heavy))
          .foregroundStyle(Theme.text)
          .frame(width: 36, height: 36)
          .background(Circle().fill(.ultraThinMaterial))
      }
      .buttonStyle(.plain)
      Spacer()
      Text(timeString(remaining))
        .font(.system(size: 14, weight: .heavy, design: .monospaced))
        .foregroundStyle(remaining < 30 ? Theme.coral : Theme.text)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
      Spacer()
      Button {
        showSelfView.toggle()
      } label: {
        Image(
          systemName: showSelfView
            ? "rectangle.inset.filled.and.person.filled"
            : "person.crop.rectangle"
        )
        .font(.system(size: 14, weight: .heavy))
        .foregroundStyle(Theme.text)
        .frame(width: 36, height: 36)
        .background(Circle().fill(.ultraThinMaterial))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 18)
    .padding(.top, 8)
    .overlay(alignment: .bottomTrailing) {
      if showSelfView {
        SelfViewPlaceholder(active: pipeline.cameraAvailable)
          .padding(.trailing, 18)
          .offset(y: 12)
      }
    }
  }

  // MARK: - Bottom bar

  private var bottomBar: some View {
    VStack(spacing: 10) {
      // Atmosphere meter.
      VStack(spacing: 4) {
        HStack {
          Text("Atmosphere")
            .font(.system(size: 10, weight: .heavy)).tracking(1.2)
            .foregroundStyle(Theme.textMuted).textCase(.uppercase)
          Spacer()
          Text(atmosphereLabel)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.text)
        }
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(Theme.border)
            Capsule()
              .fill(Theme.scoreScale)
              .frame(width: geo.size.width * CGFloat(pipeline.liveFeel))
          }
        }
        .frame(height: 5)
      }
      .padding(.horizontal, 18)

      HStack(spacing: 10) {
        listeningIndicator
          .layoutPriority(0)
        Spacer(minLength: 8)
        Button {
          app.profile.captionsEnabled.toggle()
        } label: {
          Image(systemName: showCaptions ? "captions.bubble.fill" : "captions.bubble")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.text)
            .frame(width: 36, height: 36)
            .background(Circle().fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
        .layoutPriority(1)
        Button(action: endNow) {
          Text("Done")
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Capsule().fill(Theme.accentGradient))
            .shadow(color: Theme.pink.opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .layoutPriority(1)
      }
      .padding(.horizontal, 18)
    }
    .padding(.top, 8)
    .padding(.bottom, 12)
  }

  private var atmosphereLabel: String {
    switch pipeline.liveFeel {
    case ..<0.35: return "Cool"
    case ..<0.55: return "Warming"
    case ..<0.75: return "Warm"
    default: return "Hot"
    }
  }

  private var listeningIndicator: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(pipeline.partnerSpeaking ? Theme.coral : Theme.accent)
        .frame(width: 8, height: 8)
      Text(
        pipeline.partnerSpeaking
          ? "\(config.persona.displayName) is speaking"
          : (pipeline.userSpeaking ? "You're speaking" : "Listening")
      )
      .font(.system(size: 12, weight: .bold))
      .foregroundStyle(Theme.textMuted)
      .lineLimit(1)
      .truncationMode(.tail)
    }
    .padding(.horizontal, 10).padding(.vertical, 6)
    .background(Capsule().fill(.ultraThinMaterial))
  }

  // MARK: - Winddown / daily cap

  private var winddownOverlay: some View {
    VStack {
      Spacer()
      Text("Wrapping up — finish your thought.")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Capsule().fill(Theme.accentGradient))
        .padding(.bottom, 130)
    }
  }

  private var dailyCapOverlay: some View {
    VStack(spacing: 16) {
      Spacer()
      Image(systemName: "bolt.slash.fill")
        .font(.system(size: 36, weight: .light))
        .foregroundStyle(Theme.coral)
      Text("Daily practice cap reached")
        .font(.system(size: 22, weight: .heavy))
        .foregroundStyle(Theme.text)
      Text(
        "You've used \(app.dailyLiveSessionsUsed)/\(app.dailyLiveSessionsCap) live reps today. Reviews still open."
      )
      .font(.system(size: 14))
      .multilineTextAlignment(.center)
      .foregroundStyle(Theme.textMuted)
      .padding(.horizontal, 32)
      Button(action: onClose) {
        Text("Got it")
          .font(.system(size: 15, weight: .heavy))
          .foregroundStyle(.white)
          .padding(.horizontal, 22).padding(.vertical, 12)
          .background(Capsule().fill(Theme.accentGradient))
          .shadow(color: Theme.pink.opacity(0.4), radius: 14, y: 6)
      }
      .buttonStyle(.plain)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.6).ignoresSafeArea())
  }

  // MARK: - Session lifecycle

  private func openSession() async {
    // Enforce the daily cap BEFORE opening any AV session.
    guard app.canStartLivePractice else {
      dailyCapHit = true
      return
    }
    await AvatarClipCatalog.shared.preload(persona: avatarPersona)
    let capContent = lecture.flatMap { CapstoneContentStore.shared.content(for: $0) }
    await pipeline.start(
      mode: config.mode,
      tier: config.tier,
      openingTurn: config.openingTurn,
      persona: config.persona,
      avatarPersona: avatarPersona,
      voiceId: app.profile.avatarVoiceId,
      coach: config.coach,
      lecture: lecture,
      setting: config.setting,
      userId: app.userId,
      capstonePersonaBlurb: capContent?.persona,
      capstoneSettingDescription: capContent?.setting,
      focusSkills: config.focusSkills
    )
  }

  private func tickFrame() {
    guard !ended, !dailyCapHit else { return }
    elapsed += 1
    pipeline.tick()
    if remaining <= 30 && !winddown {
      withAnimation { winddown = true }
    }
    if remaining == 0 { endNow() }
  }

  /// UX4 — fired when a user turn completes. Builds + (maybe) shows a nudge.
  /// Entirely fail-silent: any missing data simply yields no nudge.
  private func maybeNudge() {
    guard !ended, !dailyCapHit, !winddown else { return }
    let utterance = pipeline.lastUserUtterance.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !utterance.isEmpty else { return }
    let shown = nudges.handleUserTurn(
      userMessage: utterance,
      recentContext: [],
      avatarFeeling: pipeline.lastMoodTag,
      feelingIntensity: pipeline.liveFeel,
      skillTarget: config.focusSkills.first ?? lecture?.skill,
      coach: nudgeCoach,
      turnIndex: pipeline.userTurnCount)
    if shown, app.profile.soundAndHaptics, !reduceMotion {
      UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
  }

  private func endNow() {
    guard !ended else { return }
    ended = true
    scoring = true
    pipeline.stop()
    Task { await endNowAsync() }
  }

  private func endNowAsync() async {
    pipeline.tick()

    let judged = await SessionScoreService.judge(
      transcript: pipeline.signals.transcript ?? "",
      durationSeconds: elapsed,
      meanLatencySeconds: pipeline.signals.responseLatencyMean,
      voiceEnergy: pipeline.signals.meanVoiceEnergy,
      synchrony: pipeline.signals.synchrony,
      lectureScenario: lecture?.scenario,
      winCondition: nil
    )
    if let j = judged {
      pipeline.applyJudged(j)
    }

    let result = SessionScorer.score(
      lecture: lecture,
      durationSeconds: elapsed,
      tier: config.tier,
      coach: config.coach,
      signals: pipeline.signals,
      isSandbox: config.isSandbox,
      sandboxScored: config.sandboxScored,
      currentAura: app.aura
    )
    scoring = false
    onFinish(result)
  }

  private var scoringOverlay: some View {
    ZStack {
      Color.black.opacity(0.65).ignoresSafeArea()
      VStack(spacing: 14) {
        ProgressView()
          .progressViewStyle(.circular)
          .tint(Theme.accent)
          .scaleEffect(1.4)
        Text("Reviewing your session…")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Theme.text)
      }
    }
  }

  private func timeString(_ s: Int) -> String {
    String(format: "%d:%02d", s / 60, s % 60)
  }
}

// MARK: - Self view

private struct SelfViewPlaceholder: View {
  let active: Bool
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.black.opacity(0.55))
      if active {
        Image(systemName: "person.crop.rectangle.fill")
          .font(.system(size: 18))
          .foregroundStyle(Theme.text.opacity(0.7))
      } else {
        Image(systemName: "video.slash.fill")
          .font(.system(size: 14))
          .foregroundStyle(Theme.textFaint)
      }
    }
    .frame(width: 78, height: 104)
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
    )
  }
}

#Preview {
  LivePracticeView(
    lecture: Curriculum.lectures.first,
    config: SessionConfig(
      persona: .default, setting: .default, tier: .silver,
      coach: .wingman, mode: .videoVoice,
      isSandbox: false, sandboxScored: true, sandboxPremise: nil),
    onFinish: { _ in }, onClose: {}
  )
  .environment(AppState.preview)
}
