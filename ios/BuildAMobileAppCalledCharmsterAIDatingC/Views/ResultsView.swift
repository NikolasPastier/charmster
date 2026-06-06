import SwiftUI

/// Post-practice results card. Leads with her reaction + score gauge, then feel meters,
/// strengths, fixes, rewards. Low scores are calm blue — never red.
struct ResultsView: View {
    let result: SessionResult
    let lecture: Lecture
    let onContinueToQuiz: () -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                reactionCard
                gaugeBlock
                feelGrid
                workedCard
                tryNextCard
                rewardsCard
                actionRow
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .trackView("ResultsView")
    }

    private var header: some View {
        HStack {
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface).overlay(Circle().stroke(Theme.border, lineWidth: 1)))
            }
            Spacer()
            TagPill(text: lecture.title, tint: Theme.textSecondary)
        }
    }

    private var reactionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Her reaction", systemImage: "quote.opening")
                    .font(.system(size: 11, weight: .heavy)).tracking(1)
                    .foregroundStyle(Theme.textMuted)
                Text(result.reaction)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var gaugeBlock: some View {
        VStack(spacing: 10) {
            ScoreGauge(score: result.sessionScore, size: 240)
            Text(headline)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(isLow ? AnyShapeStyle(Theme.calmBlue) : AnyShapeStyle(Theme.aura))
            Text(subhead)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }

    private var headline: String {
        switch result.sessionScore {
        case 90...: return "Sparks flying 🔥"
        case 75...: return "She wanted more"
        case 60...: return "Warming up"
        case 40...: return "Friendly footing"
        default:    return "Room to grow"
        }
    }
    private var subhead: String {
        isLow
        ? "This is a starting point — not a label. One small fix changes everything."
        : "Nice work. Lock in what you did, then push your range one notch."
    }
    private var isLow: Bool { result.sessionScore < 60 }

    private var feelGrid: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 12) {
            FeelTile(label: "Comfort",  value: result.comfort,  icon: "shield.lefthalf.filled")
            FeelTile(label: "Interest", value: result.interest, icon: "sparkle")
            FeelTile(label: "Spark",    value: result.spark,    icon: "flame.fill")
            FeelTile(label: "Respect",  value: result.respect,  icon: "hand.raised.fill")
        }
    }

    private var workedCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("What worked", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.gold)
                ForEach(result.strengths, id: \.self) { s in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(Theme.gold).frame(width: 6, height: 6).padding(.top, 7)
                        Text(s).font(.system(size: 14)).foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
    }

    private var tryNextCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Try next", systemImage: "arrow.up.forward.circle.fill")
                    .font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.calmBlue)
                ForEach(result.fixes, id: \.self) { f in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(Theme.calmBlue).frame(width: 6, height: 6).padding(.top, 7)
                        Text(f).font(.system(size: 14)).foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
    }

    private var rewardsCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                RewardChip(icon: "bolt.fill", label: "+\(result.xpEarned) XP", tint: Theme.aura)
                RewardChip(icon: "circle.hexagongrid.fill", label: "+\(result.coinsEarned)", tint: AnyShapeStyle(Theme.gold))
                RewardChip(icon: "flame.fill", label: "Streak", tint: AnyShapeStyle(Theme.ember))
            }
        }
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            AuraButton(title: "Continue to quiz", icon: "questionmark.circle.fill") { onContinueToQuiz() }
            GlassButton(title: "Back to path") { onClose() }
        }
        .padding(.top, 4)
    }
}

private struct FeelTile: View {
    let label: String
    let value: Int
    let icon: String
    var body: some View {
        let low = value < 60
        return GlassCard(padding: 14, radius: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(low ? AnyShapeStyle(Theme.calmBlue) : AnyShapeStyle(Theme.aura))
                    Text(label).font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(value)").font(.system(size: 13, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.border).frame(height: 6)
                    Capsule()
                        .fill(low ? AnyShapeStyle(Theme.calmBlue) : AnyShapeStyle(Theme.aura))
                        .frame(width: max(6, CGFloat(value) / 100 * 130), height: 6)
                }
            }
        }
    }
}

private struct RewardChip: View {
    let icon: String
    let label: String
    let tint: AnyShapeStyle
    init(icon: String, label: String, tint: any ShapeStyle) {
        self.icon = icon; self.label = label; self.tint = AnyShapeStyle(tint)
    }
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(label).font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Capsule().fill(Theme.elevated))
    }
}

#Preview {
    let r = SessionResult(
        responsiveness: 82, voice: 70, face: 88, body: 71, synchrony: 76, calibration: 80,
        comfort: 78, interest: 82, spark: 74, respect: 88,
        sessionScore: 81,
        reaction: "\"That was actually really nice. I'd want to keep talking.\"",
        strengths: ["You built on what she said.", "Your warmth landed."],
        fixes: ["One playful callback would push spark higher."],
        xpEarned: 52, coinsEarned: 10
    )
    return ResultsView(result: r, lecture: Curriculum.lectures[3], onContinueToQuiz: {}, onClose: {})
        .environment(AppState()).preferredColorScheme(.dark)
}
