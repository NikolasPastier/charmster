import SwiftUI

/// Post-session results. Step 7: NO coin chip. Coins kept in model, hidden via flag.
struct ResultsView: View {
  @Environment(AppState.self) private var app
  let result: SessionResult
  let lecture: Lecture?
  /// Replay the lecture with different settings (opens the replay setup sheet).
  /// Optional so sandbox results can omit it.
  var onReplay: (() -> Void)? = nil
  let onQuiz: () -> Void
  let onDone: () -> Void

  var body: some View {
    Group {
      ScrollView {
        VStack(spacing: 16) {
          heroScore
          rewardsCard
          breakdownCard
          coachDebriefCard
          actions
        }
        .padding(18)
      }
      .background(Theme.bg.ignoresSafeArea())
    }
    .trackView("ResultsView")
  }

  private var heroScore: some View {
    VStack(spacing: 12) {
      ScoreRing(
        value: result.sessionScore, size: 180, lineWidth: 14,
        label: result.isCapstone ? "capstone" : "session")
      auraSummary
      if result.safetyCapApplied {
        TagPill(
          label: "Safety cap applied",
          systemImage: "shield.fill", tone: .coral)
      }
      if let lec = lecture {
        Text(lec.title)
          .font(.system(size: 20, weight: .heavy))
          .foregroundStyle(Theme.text)
      } else {
        Text("Sandbox session")
          .font(.system(size: 20, weight: .heavy))
          .foregroundStyle(Theme.text)
      }
    }
    .padding(.top, 16)
  }

  /// Aura is a 0–100 rolling average. Show the current value, the tier band
  /// it lands in, and the signed delta from this session so the user can
  /// see whether they moved up or down.
  private var auraSummary: some View {
    let tier = AuraTier.forAura(app.aura)
    let delta = result.auraEarned
    let deltaText: String = {
      if delta > 0 { return "▲ +\(delta)" }
      if delta < 0 { return "▼ \(delta)" }
      return "● no change"
    }()
    let deltaTone: Color = delta > 0 ? Theme.aura : (delta < 0 ? Theme.coral : Theme.textMuted)
    return HStack(spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "sparkles").foregroundStyle(tier.color)
        Text("\(app.aura)")
          .font(.system(size: 18, weight: .heavy))
          .foregroundStyle(Theme.text)
        Text(tier.title)
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(tier.color)
          .padding(.horizontal, 8).padding(.vertical, 3)
          .background(Capsule().fill(tier.color.opacity(0.15)))
      }
      Text(deltaText)
        .font(.system(size: 13, weight: .heavy))
        .foregroundStyle(deltaTone)
    }
  }

  /// Step 7: removed RewardChip(icon: "circle.hexagongrid.fill", label: "+coins").
  /// Replaced with a streak/milestone callout so the row doesn't look empty.
  private var rewardsCard: some View {
    GlassCard {
      VStack(spacing: 12) {
        SectionHeader(title: "Rewards", systemImage: "gift.fill")
        HStack(spacing: 10) {
          RewardChip(
            icon: "sparkles",
            label: auraChipLabel,
            tone: result.auraEarned >= 0 ? Theme.aura : Theme.coral)
          if result.streakKept {
            RewardChip(
              icon: "flame.fill",
              label: "Streak \(app.streakDays)",
              tone: Theme.coral)
          } else {
            RewardChip(
              icon: "rosette",
              label: milestoneLabel,
              tone: Theme.gold)
          }
          // Coins chip intentionally omitted — feature flag off.
          if app.coinsEnabled {
            RewardChip(
              icon: "circle.hexagongrid.fill",
              label: "+\(result.coinsEarned)", tone: Theme.gold)
          }
        }
      }
    }
  }

  private var auraChipLabel: String {
    let d = result.auraEarned
    if d > 0 { return "+\(d) Aura" }
    if d < 0 { return "\(d) Aura" }
    return "Aura held"
  }

  private var milestoneLabel: String {
    if result.sessionScore >= 90 { return "Dialed" }
    if result.sessionScore >= 75 { return "Solid rep" }
    return "Good start"
  }

  private var breakdownCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "Breakdown", systemImage: "chart.bar.fill")
        ScoreBar(label: "Responsiveness", value: result.responsiveness)
        ScoreBar(label: "Voice", value: result.voice)
        ScoreBar(label: "Face", value: result.face, tone: Theme.aura)
        ScoreBar(label: "Body", value: result.body, tone: Theme.aura)
        ScoreBar(label: "Synchrony", value: result.synchrony, tone: Theme.teal)
        ScoreBar(label: "Calibration", value: result.calibration, tone: Theme.gold)
        ScoreBar(label: "Comfort", value: result.comfort, tone: Theme.coral)
      }
    }
  }

  private var coachDebriefCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 10) {
          CoachAvatarView(coach: app.selectedCoach)
            .frame(width: 34, height: 34)
            .clipShape(Circle())
          Text(app.selectedCoach.humanName)
            .font(.system(size: 13, weight: .heavy))
            .tracking(1.0)
            .foregroundStyle(Theme.textMuted)
            .textCase(.uppercase)
          Spacer()
        }
        Text(
          LectureContentStore.shared.debriefText(
            coach: app.coachMode,
            result: result,
            gentleness: app.profile.feedbackGentleness)
        )
        .font(.system(size: 15))
        .foregroundStyle(Theme.text)
      }
    }
  }

  private var actions: some View {
    VStack(spacing: 10) {
      if lecture != nil {
        AuraButton(title: "Take the quiz", systemImage: "questionmark.circle", action: onQuiz)
      }
      if let onReplay {
        GlassButton(
          title: "Replay with different settings",
          systemImage: "arrow.counterclockwise", action: onReplay)
      }
      GlassButton(title: "Done", systemImage: "checkmark", action: onDone)
    }
  }
}

#Preview {
  ResultsView(
    result: SessionResult(
      id: UUID(), lectureId: "t0_l1", isCapstone: false, isSandbox: false,
      responsiveness: 78, voice: 72, face: 65, body: 70,
      synchrony: 80, calibration: 74, comfort: 68,
      sessionScore: 73, auraEarned: 36,
      streakKept: true, coinsEarned: 10, durationSeconds: 240,
      safetyCapApplied: false, createdAt: .now
    ),
    lecture: Curriculum.lectures.first,
    onQuiz: {}, onDone: {}
  )
  .environment(AppState.preview)
}
