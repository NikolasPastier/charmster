import SwiftUI

// MARK: - GlassCard

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = Theme.r22
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let sym = systemImage {
                Image(systemName: sym)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.accent.opacity(0.12)))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textMuted)
                    .textCase(.uppercase)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
            }
            Spacer()
        }
    }
}

// MARK: - TagPill

struct TagPill: View {
    let label: String
    var systemImage: String? = nil
    var tone: Tone = .neutral
    var onTap: (() -> Void)? = nil

    enum Tone { case neutral, accent, coral, gold }

    private var tint: Color {
        switch tone {
        case .neutral: return Theme.textMuted
        case .accent:  return Theme.accent
        case .coral:   return Theme.coral
        case .gold:    return Theme.gold
        }
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 6) {
                if let sys = systemImage {
                    Image(systemName: sys).font(.system(size: 10, weight: .bold))
                }
                Text(label).font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

// MARK: - AuraButton (primary)

struct AuraButton: View {
    let title: String
    var systemImage: String? = nil
    var tone: Tone = .accent
    var enabled: Bool = true
    let action: () -> Void

    enum Tone { case accent, coral, gold }

    private var gradient: LinearGradient {
        switch tone {
        case .accent: return Theme.accentGradient
        case .coral:  return LinearGradient(colors: [Theme.coral, Color(hex: 0xB73B40)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gold:   return Theme.goldGradient
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let sys = systemImage {
                    Image(systemName: sys).font(.system(size: 16, weight: .bold))
                }
                Text(title).font(.system(size: 16, weight: .heavy))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(gradient)
                    .opacity(enabled ? 1 : 0.4)
            )
            .shadow(color: (tone == .accent ? Theme.accent : Theme.gold).opacity(enabled ? 0.4 : 0), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - GlassButton (secondary)

struct GlassButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let sys = systemImage {
                    Image(systemName: sys).font(.system(size: 14, weight: .bold))
                }
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ScoreRing

struct ScoreRing: View {
    let value: Int    // 0..100
    var size: CGFloat = 110
    var lineWidth: CGFloat = 10
    var label: String? = nil
    var tone: Color = Theme.accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.border, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(value, 0), 100)) / 100.0)
                .stroke(
                    AngularGradient(colors: [tone, tone.opacity(0.7)], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: size * 0.32, weight: .heavy))
                    .foregroundStyle(Theme.text)
                if let label {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                        .tracking(1.0).textCase(.uppercase)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - ScoreBar (horizontal)

struct ScoreBar: View {
    let label: String
    let value: Int          // 0..100
    var tone: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.border)
                    Capsule()
                        .fill(tone)
                        .frame(width: geo.size.width * CGFloat(min(max(value, 0), 100)) / 100.0)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Reward chip

struct RewardChip: View {
    let icon: String
    let label: String
    var tone: Color = Theme.accent

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tone)
            Text(label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tone.opacity(0.3), lineWidth: 1)
        )
    }
}
