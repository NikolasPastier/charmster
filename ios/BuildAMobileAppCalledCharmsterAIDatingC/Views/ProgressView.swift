import SwiftUI

/// Asymmetric bento Progress dashboard.
struct ProgressDashboardView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                bento
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .trackView("ProgressView")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Progress")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Your Aura, level and momentum.")
                .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 20)
    }

    private var bento: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                auraTile
                VStack(spacing: 12) {
                    coinsTile
                    streakTile
                }
                .frame(maxWidth: .infinity)
            }
            levelTile
            scoreChartTile
            HStack(spacing: 12) {
                strongestTile
                focusTile
            }
        }
    }

    private var auraTile: some View {
        GlassCard(padding: 16) {
            VStack(spacing: 10) {
                AuraRing(progress: app.aura / 100,
                         label: "\(Int(app.aura))",
                         sublabel: "Aura · \(app.auraBand)",
                         size: 150)
                Text("Your skill EMA")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 200)
    }

    private var coinsTile: some View {
        GlassCard(padding: 14, radius: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Charm Coins", systemImage: "circle.hexagongrid.fill")
                    .font(.system(size: 11, weight: .heavy)).tracking(1)
                    .foregroundStyle(Theme.gold)
                Text("\(app.charmCoins)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var streakTile: some View {
        GlassCard(padding: 14, radius: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Streak", systemImage: "flame.fill")
                    .font(.system(size: 11, weight: .heavy)).tracking(1)
                    .foregroundStyle(Theme.ember)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(app.streakDays)").font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary).monospacedDigit()
                    Text("days").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var levelTile: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level \(app.level) · \(app.levelTitle)")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(app.totalXP) / \(app.nextLevelXP) XP")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary).monospacedDigit()
                    }
                    Spacer()
                    Image(systemName: "rosette").font(.system(size: 28))
                        .foregroundStyle(Theme.aura)
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.border).frame(height: 10)
                    GeometryReader { geo in
                        Capsule().fill(Theme.aura)
                            .frame(width: max(10, geo.size.width * app.levelProgress), height: 10)
                            .shadow(color: Theme.auraGlow, radius: 12)
                    }
                    .frame(height: 10)
                }
            }
        }
    }

    private var scoreChartTile: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Score over time", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.calmBlue)
                    Spacer()
                    Text("Last \(app.recentScores.count)")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textMuted)
                }
                ScoreLineChart(values: app.recentScores)
                    .frame(height: 110)
            }
        }
    }

    private var strongestTile: some View {
        GlassCard(padding: 14, radius: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("STRONGEST SKILL").font(.system(size: 10, weight: .heavy)).tracking(1)
                    .foregroundStyle(Theme.textMuted)
                Text("Presence")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.aura)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var focusTile: some View {
        GlassCard(padding: 14, radius: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("FOCUS AREA").font(.system(size: 10, weight: .heavy)).tracking(1)
                    .foregroundStyle(Theme.textMuted)
                Text(app.focusAreas.first?.rawValue ?? "Openers")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.calmBlue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ScoreLineChart: View {
    let values: [Int]
    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                // Grid
                ForEach(0..<4, id: \.self) { i in
                    let y = geo.size.height * CGFloat(i) / 3
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Theme.border, lineWidth: 0.5)
                }
                // Line
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(Theme.scoreScale, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: Theme.pink.opacity(0.4), radius: 10)
                // Dots
                ForEach(Array(pts.enumerated()), id: \.offset) { _, pt in
                    Circle().fill(Theme.gold).frame(width: 6, height: 6).position(pt)
                }
            }
        }
    }
    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            let y = size.height - (CGFloat(v) / 100) * size.height
            return CGPoint(x: CGFloat(i) * stepX, y: y)
        }
    }
}

#Preview {
    ProgressDashboardView().environment(AppState()).preferredColorScheme(.dark)
}
