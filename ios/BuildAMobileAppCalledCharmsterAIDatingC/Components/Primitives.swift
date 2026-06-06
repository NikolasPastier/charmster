import SwiftUI

// MARK: - Backgrounds

/// Charmster app background: near-black violet with floating gradient orbs.
struct AuraBackground: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            // Floating blurred orbs
            Circle()
                .fill(Theme.purple.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -140, y: -260)
            Circle()
                .fill(Theme.pink.opacity(0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 160, y: -120)
            Circle()
                .fill(Theme.ember.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -120, y: 320)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Buttons

/// Aura-gradient primary button with glow.
struct AuraButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.system(size: 17, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(.white)
            .background(Theme.aura, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.auraGlow, radius: 24, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }
}

/// Glass secondary button.
struct GlassButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(Theme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cards

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Pills

struct StatPill: View {
    let icon: String
    let value: String
    var tint: Color = Theme.gold
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).font(.system(size: 14, weight: .bold)).monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(
            Capsule().fill(Theme.surface)
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        )
    }
}

struct TagPill: View {
    let text: String
    var tint: Color = Theme.textSecondary
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.12)))
    }
}

// MARK: - Rings & Bars

/// Aura ring with a numeric center value, gradient stroke, soft glow.
struct AuraRing: View {
    let progress: Double    // 0...1
    let label: String
    let sublabel: String?
    var size: CGFloat = 180
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.border, lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(Theme.aura, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.auraGlow, radius: 16)
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: size * 0.28, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.aura)
                if let sublabel {
                    Text(sublabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

/// Semicircular score gauge: cool blue if low, aura if high.
struct ScoreGauge: View {
    let score: Int  // 0...100
    var size: CGFloat = 220
    var body: some View {
        let pct = Double(max(0, min(100, score))) / 100
        let isLow = score < 60
        let fill: AnyShapeStyle = isLow
            ? AnyShapeStyle(Theme.calmBlue)
            : AnyShapeStyle(Theme.aura)
        ZStack {
            // Track
            Semicircle()
                .stroke(Theme.border, style: StrokeStyle(lineWidth: 18, lineCap: .round))
            // Fill
            Semicircle()
                .trim(from: 0, to: pct)
                .stroke(fill, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .shadow(color: isLow ? Theme.calmBlue.opacity(0.4) : Theme.auraGlow, radius: 18)
            VStack(spacing: 4) {
                Text("\(score)")
                    .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isLow ? AnyShapeStyle(Theme.calmBlue) : AnyShapeStyle(Theme.aura))
                Text(Theme.scoreBand(score))
                    .font(.system(size: 13, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textSecondary)
            }
            .offset(y: size * 0.10)
        }
        .frame(width: size, height: size * 0.62)
    }
}

private struct Semicircle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height * 2) / 2 - 9
        let c = CGPoint(x: rect.midX, y: rect.maxY - 8)
        p.addArc(center: c, radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        return p
    }
}

/// Horizontal feel-meter bar. Cool blue if value low, gradient if high.
struct FeelMeter: View {
    let label: String
    let value: Int   // 0...100
    var icon: String = "heart.fill"
    var body: some View {
        let isLow = value < 60
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(isLow ? AnyShapeStyle(Theme.calmBlue) : AnyShapeStyle(Theme.aura))
                Text(label).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(value)").font(.system(size: 13, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border.opacity(0.6)).frame(height: 8)
                Capsule()
                    .fill(isLow ? AnyShapeStyle(Theme.calmBlue) : AnyShapeStyle(Theme.aura))
                    .frame(width: max(8, CGFloat(value) / 100 * 240), height: 8)
            }
        }
    }
}

/// Thin Aura gradient progress bar (top of onboarding etc).
struct AuraProgressBar: View {
    let progress: Double // 0...1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border).frame(height: 6)
                Capsule()
                    .fill(Theme.aura)
                    .frame(width: max(6, geo.size.width * max(0, min(1, progress))), height: 6)
                    .shadow(color: Theme.auraGlow, radius: 8)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }
}
