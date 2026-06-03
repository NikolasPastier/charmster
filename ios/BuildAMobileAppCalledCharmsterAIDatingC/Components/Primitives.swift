import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var variant: Variant = .accent
    let action: () -> Void

    enum Variant { case accent, coral, outline }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous)
                    .stroke(strokeColor, lineWidth: variant == .outline ? 1.5 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.rLarge, style: .continuous))
            .shadow(color: glow, radius: 18, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch variant {
        case .accent: return .black
        case .coral: return .white
        case .outline: return Theme.textPrimary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .accent:
            LinearGradient(colors: [Theme.accent, Color(hex: 0x00C264)],
                           startPoint: .top, endPoint: .bottom)
        case .coral:
            LinearGradient(colors: [Theme.coral, Color(hex: 0xE03A40)],
                           startPoint: .top, endPoint: .bottom)
        case .outline:
            Color.white.opacity(0.04)
        }
    }

    private var strokeColor: Color {
        variant == .outline ? Color.white.opacity(0.18) : .clear
    }

    private var glow: Color {
        switch variant {
        case .accent: return Theme.accent.opacity(0.35)
        case .coral: return Theme.coral.opacity(0.35)
        case .outline: return .clear
        }
    }
}

struct StatPill: View {
    let icon: String
    let text: String
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 1))
    }
}

struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

struct ProgressRing: View {
    let progress: Double // 0...1
    var size: CGFloat = 180
    var lineWidth: CGFloat = 14
    var tint: Color = Theme.accent
    var label: String? = nil
    var value: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [tint, tint.opacity(0.6), tint]),
                                    center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.5), radius: 12)

            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: size * 0.28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                if let label {
                    Text(label.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct LinearProgressBar: View {
    let progress: Double
    var height: CGFloat = 10
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.7)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * max(0.001, min(progress, 1)))
                    .shadow(color: tint.opacity(0.5), radius: 6)
            }
        }
        .frame(height: height)
    }
}

struct ScoreBar: View {
    let label: String
    let score: Int // 0...10
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(score)/10")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
            }
            LinearProgressBar(progress: Double(score) / 10.0, height: 8, tint: tint)
        }
    }
}
