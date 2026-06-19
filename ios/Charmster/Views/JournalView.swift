import SwiftUI

/// Progress Journal (P6). Reads existing score data from `app.journal` — no new
/// source of truth. Shows the Aura trend, per-dimension trends, week-over-week
/// deltas in plain language, personal bests, and the coach's memory line.
struct JournalView: View {
  @Environment(AppState.self) private var app

  var body: some View {
    ScrollView {
      VStack(spacing: 14) {
        if app.journal.isEmpty {
          emptyState
        } else {
          coachMemoryCard
          auraTrendCard
          weekOverWeekCard
          dimensionsCard
          recentCard
        }
      }
      .padding(18)
    }
    .background(AuraBackground())
    .navigationTitle("Progress Journal")
    .navigationBarTitleDisplayMode(.inline)
    .trackView("JournalView")
  }

  private var emptyState: some View {
    GlassCard {
      VStack(spacing: 10) {
        Image(systemName: "chart.line.uptrend.xyaxis")
          .font(.system(size: 36)).foregroundStyle(Theme.accent)
        Text("Your journal starts after your first session")
          .font(.system(size: 16, weight: .heavy))
          .multilineTextAlignment(.center)
          .foregroundStyle(Theme.text)
        Text(
          "Every completed session logs your scores so \(app.selectedCoach.humanName) can track your growth."
        )
        .font(.system(size: 13)).multilineTextAlignment(.center)
        .foregroundStyle(Theme.textMuted)
      }
      .frame(maxWidth: .infinity).padding(.vertical, 10)
    }
  }

  @ViewBuilder
  private var coachMemoryCard: some View {
    if let memory = app.coachMemoryLine {
      GlassCard {
        HStack(spacing: 12) {
          CoachAvatarView(coach: app.selectedCoach)
            .frame(width: 44, height: 44).clipShape(Circle())
          VStack(alignment: .leading, spacing: 3) {
            Text(app.selectedCoach.humanName)
              .font(.system(size: 12, weight: .heavy)).tracking(1.0)
              .foregroundStyle(Theme.accent).textCase(.uppercase)
            Text(memory)
              .font(.system(size: 14)).foregroundStyle(Theme.text)
          }
        }
      }
    }
  }

  private var auraTrendCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          SectionHeader(title: "Aura over time", systemImage: "sparkles")
          Spacer()
          Text("\(app.aura)")
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(AuraTier.forAura(app.aura).color)
        }
        Sparkline(values: app.auraTrend, tone: Theme.aura, fill: true)
          .frame(height: 64)
        Text(AuraTier.forAura(app.aura).blurb)
          .font(.system(size: 12)).foregroundStyle(Theme.textMuted)
      }
    }
  }

  private var weekOverWeekCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        SectionHeader(title: "This week", systemImage: "calendar")
        let deltas = JournalEntry.dimensionKeys.compactMap { key -> (String, Int, String)? in
          guard let d = app.weekOverWeekDelta(key) else { return nil }
          return (key, d.pct, d.phrase)
        }
        if deltas.isEmpty {
          Text(
            "Keep practicing — week-over-week trends appear once you have two weeks of sessions."
          )
          .font(.system(size: 13)).foregroundStyle(Theme.textMuted)
        } else {
          ForEach(deltas, id: \.0) { _, pct, phrase in
            HStack(spacing: 8) {
              Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(pct >= 0 ? Theme.good : Theme.coral)
              Text(phrase.prefix(1).capitalized + phrase.dropFirst())
                .font(.system(size: 14)).foregroundStyle(Theme.text)
              Spacer()
            }
          }
        }
      }
    }
  }

  private var dimensionsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "Per-skill trend", systemImage: "chart.bar.xaxis")
        ForEach(JournalEntry.dimensionKeys, id: \.self) { key in
          let trend = app.dimensionTrend(key)
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
              Text(key).font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.text)
              if let best = app.dimensionBests[key] {
                Text("Best \(best)").font(.system(size: 11)).foregroundStyle(Theme.gold)
              }
            }
            .frame(width: 110, alignment: .leading)
            Sparkline(values: trend, tone: Theme.scoreColor(for: trend.last ?? 0), fill: false)
              .frame(height: 34)
            Text("\(trend.last ?? 0)")
              .font(.system(size: 15, weight: .heavy))
              .foregroundStyle(Theme.text)
              .frame(width: 34, alignment: .trailing)
          }
        }
      }
    }
  }

  private var recentCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        SectionHeader(title: "Recent sessions", systemImage: "clock.arrow.circlepath")
        ForEach(app.journal.suffix(6).reversed()) { e in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(e.skill).font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.text)
              Spacer()
              Text("\(e.sessionScore)")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Theme.scoreColor(for: e.sessionScore))
            }
            Text(e.feltLine).font(.system(size: 12)).foregroundStyle(Theme.textMuted)
            Text(e.timestamp.formatted(.relative(presentation: .named)))
              .font(.system(size: 11)).foregroundStyle(Theme.textMuted)
          }
          .padding(.vertical, 4)
          if e.id != app.journal.suffix(6).reversed().last?.id {
            Divider().overlay(Theme.border)
          }
        }
      }
    }
  }
}

// MARK: - Sparkline

/// Lightweight inline trend line over a series of 0–100 values. No external
/// chart dependency — just a normalized Path.
struct Sparkline: View {
  let values: [Int]
  var tone: Color = Theme.accent
  var fill: Bool = false

  var body: some View {
    GeometryReader { geo in
      let pts = points(in: geo.size)
      ZStack {
        if fill, pts.count > 1 {
          Path { p in
            p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
            for pt in pts { p.addLine(to: pt) }
            p.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
            p.closeSubpath()
          }
          .fill(
            LinearGradient(
              colors: [tone.opacity(0.32), tone.opacity(0.02)],
              startPoint: .top, endPoint: .bottom))
        }
        if pts.count > 1 {
          Path { p in
            p.move(to: pts[0])
            for pt in pts.dropFirst() { p.addLine(to: pt) }
          }
          .stroke(tone, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        } else if let only = pts.first {
          Circle().fill(tone).frame(width: 6, height: 6).position(only)
        }
      }
    }
  }

  private func points(in size: CGSize) -> [CGPoint] {
    guard !values.isEmpty else { return [] }
    let maxV = max(values.max() ?? 100, 1)
    let minV = min(values.min() ?? 0, maxV - 1)
    let span = max(maxV - minV, 1)
    let stepX = values.count > 1 ? size.width / CGFloat(values.count - 1) : 0
    return values.enumerated().map { i, v in
      let nx = stepX * CGFloat(i)
      let ny = size.height - (CGFloat(v - minV) / CGFloat(span)) * size.height
      return CGPoint(x: nx, y: ny)
    }
  }
}

// MARK: - Personal-best toast (overlay)

struct PersonalBestToast: View {
  let dimension: String
  let value: Int

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "trophy.fill")
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(.black)
      VStack(alignment: .leading, spacing: 1) {
        Text("New personal best")
          .font(.system(size: 13, weight: .heavy)).foregroundStyle(.black)
        Text("\(dimension) hit \(value)")
          .font(.system(size: 12)).foregroundStyle(.black.opacity(0.7))
      }
    }
    .padding(.horizontal, 16).padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.goldGradient)
    )
    .auraGlow(color: Theme.gold, radius: 20, intensity: 0.5)
    .padding(.horizontal, 24)
  }
}

#Preview {
  NavigationStack { JournalView().environment(AppState.preview) }
}
