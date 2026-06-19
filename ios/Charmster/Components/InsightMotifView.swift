import SwiftUI

/// LV6 — In-app vector motif drawn in SwiftUI, always renders with zero
/// network. Selected by the lecture's `insightVisual` key. The card is never
/// blank: when no key matches, a per-track motif is chosen deterministically.
///
/// Seam for later: each case can accept an optional `imageOverlay: URL?` once
/// generated teaching images are ready — the motif stays as the floor and the
/// image fades in on top.
struct InsightMotifView: View {
  let theme: String

  var body: some View {
    ZStack {
      Color(hex: 0x100D1A)  // deep card base, distinct from bg
      motif
      // Subtle upper-right aura glow matching the brand palette
      RadialGradient(
        colors: [Theme.purple.opacity(0.12), Theme.pink.opacity(0.08), .clear],
        center: UnitPoint(x: 0.85, y: 0.12),
        startRadius: 10,
        endRadius: 220
      )
      .blur(radius: 16)
      .allowsHitTesting(false)
    }
  }

  @ViewBuilder
  private var motif: some View {
    switch theme {
    case "firstImpressions":  FirstImpressionsMotif()
    case "presence":          PresenceMotif()
    case "conversationFlow":  ConversationFlowMotif()
    case "confidence":        ConfidenceMotif()
    case "bodyLanguage":      BodyLanguageMotif()
    case "vulnerability":     VulnerabilityMotif()
    case "readingSignals":    ReadingSignalsMotif()
    case "abundance":         AbundanceMotif()
    default:                  DefaultAuraMotif()
    }
  }
}

// MARK: - firstImpressions
// Expanding elliptical rings from a warm center — the ripple of first contact.

private struct FirstImpressionsMotif: View {
  var body: some View {
    Canvas { ctx, size in
      let cx = size.width * 0.5
      let cy = size.height * 0.48
      for i in 0..<6 {
        let f = CGFloat(i + 1) / 6.0
        let rw = size.width * 0.18 + size.width * 0.54 * f
        let rh = rw * 0.55
        let alpha = Double(1.0 - f * 0.8)
        let col: Color = i < 3 ? Color(hex: 0xFF4D94) : Color(hex: 0xFFC23D)
        ctx.stroke(
          Path { p in
            p.addEllipse(in: CGRect(x: cx - rw, y: cy - rh, width: rw * 2, height: rh * 2))
          },
          with: .color(col.opacity(alpha * 0.42)),
          lineWidth: max(0.5, 2.0 - CGFloat(i) * 0.28)
        )
      }
      // Warm center dot
      ctx.fill(
        Path(ellipseIn: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10)),
        with: .color(Color(hex: 0xFF4D94).opacity(0.8))
      )
    }
  }
}

// MARK: - presence
// Three concentric circles — calm, centered, still.

private struct PresenceMotif: View {
  var body: some View {
    Canvas { ctx, size in
      let cx = size.width * 0.5
      let cy = size.height * 0.44
      let radii: [(CGFloat, Color)] = [
        (size.width * 0.14, Color(hex: 0xA24BFF)),
        (size.width * 0.28, Color(hex: 0xFF4D94)),
        (size.width * 0.44, Color(hex: 0xFFC23D)),
      ]
      for (r, col) in radii {
        ctx.stroke(
          Path { p in
            p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
          },
          with: .color(col.opacity(0.32)),
          lineWidth: 1.5
        )
      }
      ctx.fill(
        Path(ellipseIn: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8)),
        with: .color(Color(hex: 0xA24BFF).opacity(0.75))
      )
    }
  }
}

// MARK: - conversationFlow
// Two interleaved S-curves flowing across — back-and-forth dialogue.

private struct ConversationFlowMotif: View {
  var body: some View {
    Canvas { ctx, size in
      let w = size.width, h = size.height
      // Upper curve — pink (your move)
      var top = Path()
      top.move(to: CGPoint(x: w * 0.05, y: h * 0.38))
      top.addCurve(
        to: CGPoint(x: w * 0.95, y: h * 0.38),
        control1: CGPoint(x: w * 0.28, y: h * 0.10),
        control2: CGPoint(x: w * 0.72, y: h * 0.66)
      )
      ctx.stroke(top, with: .color(Color(hex: 0xFF4D94).opacity(0.48)), lineWidth: 2.0)

      // Lower curve — gold (her reply)
      var bot = Path()
      bot.move(to: CGPoint(x: w * 0.05, y: h * 0.56))
      bot.addCurve(
        to: CGPoint(x: w * 0.95, y: h * 0.56),
        control1: CGPoint(x: w * 0.28, y: h * 0.84),
        control2: CGPoint(x: w * 0.72, y: h * 0.28)
      )
      ctx.stroke(bot, with: .color(Color(hex: 0xFFC23D).opacity(0.42)), lineWidth: 2.0)

      // Intersection dot
      ctx.fill(
        Path(ellipseIn: CGRect(x: w * 0.5 - 4, y: h * 0.47 - 4, width: 8, height: 8)),
        with: .color(Color(hex: 0xFF7A45).opacity(0.7))
      )
    }
  }
}

// MARK: - confidence
// Five ascending bars — steady climb, warm gradient left to right.

private struct ConfidenceMotif: View {
  var body: some View {
    Canvas { ctx, size in
      let barW = size.width * 0.09
      let gap = size.width * 0.055
      let base = size.height * 0.72
      let totalW = 5 * barW + 4 * gap
      let startX = (size.width - totalW) / 2
      let heights: [CGFloat] = [0.15, 0.30, 0.46, 0.62, 0.78].map { $0 * size.height * 0.65 }
      let colors: [Color] = [
        Color(hex: 0xA24BFF), Color(hex: 0xCC3EBE),
        Color(hex: 0xFF4D94), Color(hex: 0xFF7A45), Color(hex: 0xFFC23D),
      ]
      for (i, (barH, col)) in zip(heights, colors).enumerated() {
        let x = startX + CGFloat(i) * (barW + gap)
        ctx.fill(
          Path(roundedRect: CGRect(x: x, y: base - barH, width: barW, height: barH),
               cornerRadius: barW / 2),
          with: .color(col.opacity(0.52))
        )
      }
    }
  }
}

// MARK: - bodyLanguage
// Open-V spread from a center point — open posture, approachable frame.

private struct BodyLanguageMotif: View {
  var body: some View {
    Canvas { ctx, size in
      let cx = size.width * 0.5
      let cy = size.height * 0.56

      // Left arm
      var left = Path()
      left.move(to: CGPoint(x: cx, y: cy))
      left.addLine(to: CGPoint(x: cx - size.width * 0.32, y: cy - size.height * 0.32))
      ctx.stroke(left, with: .color(Color(hex: 0xFF4D94).opacity(0.50)), lineWidth: 2.5)

      // Right arm
      var right = Path()
      right.move(to: CGPoint(x: cx, y: cy))
      right.addLine(to: CGPoint(x: cx + size.width * 0.32, y: cy - size.height * 0.32))
      ctx.stroke(right, with: .color(Color(hex: 0xFFC23D).opacity(0.50)), lineWidth: 2.5)

      // Vertical spine
      var spine = Path()
      spine.move(to: CGPoint(x: cx, y: cy))
      spine.addLine(to: CGPoint(x: cx, y: cy + size.height * 0.16))
      ctx.stroke(spine, with: .color(Color(hex: 0xA24BFF).opacity(0.40)), lineWidth: 1.5)

      // Origin dot
      ctx.fill(
        Path(ellipseIn: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10)),
        with: .color(Color(hex: 0xFF7A45).opacity(0.75))
      )
    }
  }
}

// MARK: - vulnerability
// Three overlapping soft circles — shared space, openness.

private struct VulnerabilityMotif: View {
  var body: some View {
    Canvas { ctx, size in
      let cx = size.width * 0.5
      let cy = size.height * 0.45
      let r = size.width * 0.24
      let positions: [(CGFloat, CGFloat, Color)] = [
        (cx - r * 0.55, cy - r * 0.30, Color(hex: 0xA24BFF)),
        (cx + r * 0.55, cy - r * 0.30, Color(hex: 0xFF4D94)),
        (cx,            cy + r * 0.45, Color(hex: 0xFFC23D)),
      ]
      for (x, y, col) in positions {
        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(col.opacity(0.14)))
        ctx.stroke(Path(ellipseIn: rect), with: .color(col.opacity(0.30)), lineWidth: 1.0)
      }
    }
  }
}

// MARK: - readingSignals
// Radar arcs expanding from a focal point — reading the room.

private struct ReadingSignalsMotif: View {
  var body: some View {
    Canvas { ctx, size in
      let origin = CGPoint(x: size.width * 0.14, y: size.height * 0.82)
      let radii: [CGFloat] = [
        size.width * 0.22, size.width * 0.40,
        size.width * 0.58, size.width * 0.76,
      ]
      let colors: [Color] = [
        Color(hex: 0xA24BFF), Color(hex: 0xFF4D94),
        Color(hex: 0xFF7A45), Color(hex: 0xFFC23D),
      ]
      for (r, col) in zip(radii, colors) {
        var arc = Path()
        arc.addArc(
          center: origin, radius: r,
          startAngle: .degrees(-90), endAngle: .degrees(-8),
          clockwise: false
        )
        ctx.stroke(arc, with: .color(col.opacity(0.38)), lineWidth: 1.5)
      }
      ctx.fill(
        Path(ellipseIn: CGRect(x: origin.x - 4, y: origin.y - 4, width: 8, height: 8)),
        with: .color(Color(hex: 0xA24BFF).opacity(0.8))
      )
    }
  }
}

// MARK: - abundance
// Scattered warm dots at varying sizes — options, richness, many choices.

private struct AbundanceMotif: View {
  var body: some View {
    Canvas { ctx, size in
      // (relX, relY, radius, color)
      let dots: [(CGFloat, CGFloat, CGFloat, Color)] = [
        (0.20, 0.22, 10, Color(hex: 0xA24BFF)),
        (0.50, 0.14, 14, Color(hex: 0xFF4D94)),
        (0.80, 0.28, 7,  Color(hex: 0xFFC23D)),
        (0.14, 0.50, 6,  Color(hex: 0xFF7A45)),
        (0.65, 0.38, 10, Color(hex: 0xA24BFF)),
        (0.86, 0.58, 8,  Color(hex: 0xFF4D94)),
        (0.35, 0.54, 12, Color(hex: 0xFFC23D)),
        (0.72, 0.68, 6,  Color(hex: 0xFF7A45)),
        (0.44, 0.34, 5,  Color(hex: 0xA24BFF)),
        (0.58, 0.56, 9,  Color(hex: 0xFF4D94)),
      ]
      for (rx, ry, r, col) in dots {
        let x = size.width * rx
        let y = size.height * ry
        ctx.fill(
          Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
          with: .color(col.opacity(0.44))
        )
      }
    }
  }
}

// MARK: - default
// Soft aura glow — used for tracks without a specific motif key.

private struct DefaultAuraMotif: View {
  var body: some View {
    RadialGradient(
      colors: [Theme.pink.opacity(0.20), Theme.gold.opacity(0.10), .clear],
      center: UnitPoint(x: 0.5, y: 0.35),
      startRadius: 20,
      endRadius: 240
    )
    .blur(radius: 18)
  }
}

// MARK: - Preview

#Preview {
  let themes = [
    "firstImpressions", "presence", "conversationFlow", "confidence",
    "bodyLanguage", "vulnerability", "readingSignals", "abundance",
  ]
  return ScrollView {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      ForEach(themes, id: \.self) { t in
        ZStack(alignment: .bottomLeading) {
          InsightMotifView(theme: t)
          Text(t).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textMuted)
            .padding(8)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
    }
    .padding(12)
  }
  .background(Theme.bg.ignoresSafeArea())
}
