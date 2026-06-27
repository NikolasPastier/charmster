import SwiftUI

/// Post-session results. Step 7: NO coin chip. Coins kept in model, hidden via flag.
struct ResultsView: View {
  @Environment(AppState.self) private var app
  let result: SessionResult
  let lecture: Lecture?
  var onReplay: (() -> Void)? = nil
  let onQuiz: () -> Void
  let onDone: () -> Void

  var body: some View {
    Group {
      ScrollView {
        VStack(spacing: 16) {
          heroScore
          rewardsCard
          feedbackCard
          breakdownCard
          actions
        }
        .padding(18)
      }
      .background(AuraBackground())
    }
    .trackView("ResultsView")
  }

  // MARK: - Hero score

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

  // MARK: - Rewards

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

  // MARK: - Feedback card (Feedback Engine Part 4 order)

  private var feedbackCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 14) {

        // 1 · Reaction line (her felt experience)
        if let line = result.reactionLine, !line.isEmpty {
          Text("\u{201C}\(line)\u{201D}")
            .font(.system(size: 15, weight: .semibold).italic())
            .foregroundStyle(Theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 2)
        }

        // 2 · Four feel meters
        SectionHeader(title: "How she felt", systemImage: "heart.text.square.fill")
        ScoreBar(label: "Comfort",  value: result.comfort,          tone: Theme.coral)
        ScoreBar(label: "Interest", value: result.interest ?? 50,   tone: Theme.aura)
        ScoreBar(label: "Spark",    value: result.spark   ?? 50,    tone: Theme.gold)
        ScoreBar(label: "Respect",  value: result.respect ?? 50,    tone: Theme.teal)

        // 3 · Strengths
        if let strengths = result.strengths, !strengths.isEmpty {
          Divider().overlay(Theme.border)
          Text("What worked")
            .font(.system(size: 12, weight: .bold)).tracking(1.2)
            .foregroundStyle(Theme.textMuted).textCase(.uppercase)
          ForEach(strengths, id: \.self) { s in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.good)
              Text(s)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }

        // 4 · Fixes (dimension-labelled)
        if let fixes = result.fixes, !fixes.isEmpty {
          Divider().overlay(Theme.border)
          Text("Next time")
            .font(.system(size: 12, weight: .bold)).tracking(1.2)
            .foregroundStyle(Theme.textMuted).textCase(.uppercase)
          ForEach(fixes, id: \.self) { fix in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.accent)
              Text(fix)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
    }
  }

  // MARK: - Raw signals breakdown

  private var breakdownCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "Raw signals", systemImage: "chart.bar.fill")
        ScoreBar(label: "Responsiveness", value: result.responsiveness)
        ScoreBar(label: "Calibration",    value: result.calibration,   tone: Theme.gold)
        if result.voice > 0 {
          ScoreBar(label: "Voice",   value: result.voice)
        }
        if result.synchrony > 0 {
          ScoreBar(label: "Synchrony", value: result.synchrony, tone: Theme.teal)
        }
        if result.cameraUsed != false {
          ScoreBar(label: "Face", value: result.face, tone: Theme.aura)
          ScoreBar(label: "Body", value: result.body, tone: Theme.aura)
        }
      }
    }
  }

  // MARK: - Actions

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
      id: UUID(), lectureId: "1.1", isCapstone: false, isSandbox: false,
      responsiveness: 74, voice: 68, face: 71, body: 65,
      synchrony: 77, calibration: 72, comfort: 64,
      sessionScore: 70, auraEarned: 3,
      streakKept: true, coinsEarned: 10, durationSeconds: 240,
      safetyCapApplied: false, createdAt: .now,
      cameraUsed: true,
      interest: 66, spark: 58, respect: 80,
      reactionLine: "She warmed up when you asked about the book — that callback landed.",
      strengths: ["Good callback on her earlier mention", "Clean turn-taking throughout"],
      fixes: [
        "Calibration: Back off when she gives one-word answers — she was cooling.",
        "Spark: Add one playful tease early before going deep.",
      ]
    ),
    lecture: Curriculum.lectures.first,
    onQuiz: {}, onDone: {}
  )
  .environment(AppState.preview)
}
