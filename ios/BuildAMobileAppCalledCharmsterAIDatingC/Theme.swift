import SwiftUI

/// Centralized design tokens for Charmster.
/// Dark, cinematic, premium "noir-tech" base lit by a warm love-spectrum gradient.
enum Theme {
    // MARK: - Base neutrals (near-black with subtle violet tint, never pure black)
    static let bg            = Color(hex: 0x0B0910) // app background
    static let surface       = Color(hex: 0x14111C) // cards, sheets, tab bar
    static let surfaceRaised = Color(hex: 0x1D1928) // modals, active tiles (elevated)
    static let border        = Color(hex: 0x2C2740) // strokes / dividers
    static let divider       = Color(hex: 0x2C2740)

    // MARK: - Type
    static let text          = Color(hex: 0xF6F4FA)
    static let textMuted     = Color(hex: 0xABA4BD)
    static let textFaint     = Color(hex: 0x6C6580) // hints, disabled, locked

    // MARK: - Love spectrum (warm accents)
    static let purple        = Color(hex: 0xA24BFF)
    static let pink          = Color(hex: 0xFF4D94) // PRIMARY brand
    static let red           = Color(hex: 0xFF3B5E)
    static let orange        = Color(hex: 0xFF7A45)
    static let gold          = Color(hex: 0xFFC23D)

    // MARK: - Cool feedback (calm, "room to grow")
    static let blue          = Color(hex: 0x4C8DFF)
    static let teal          = Color(hex: 0x35D6C5)
    static let violet        = Color(hex: 0x8A5CFF)

    // MARK: - Semantic aliases (kept for existing call sites)
    static let accent        = pink           // brand / CTA / progress
    static let accentDim     = purple
    static let coral         = red            // boss / streak / urgency
    static let xp            = gold           // XP chips
    static let aura          = pink           // brand aura halo
    static let auraGlow      = red

    // MARK: - Semantic states
    static let good          = teal
    static let warn          = gold
    static let bad           = Color(hex: 0xFF6B6B) // true-error red (separate from celebratory brand red)

    // MARK: - Signature gradients
    /// Aura — the full love spectrum. topLeading → bottomTrailing.
    static let auraGradient = LinearGradient(
        colors: [
            Color(hex: 0xA24BFF),
            Color(hex: 0xFF4D94),
            Color(hex: 0xFF3B5E),
            Color(hex: 0xFF7A45),
            Color(hex: 0xFFC23D)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Primary CTA gradient — a warm slice of the aura.
    static let accentGradient = LinearGradient(
        colors: [
            Color(hex: 0xA24BFF),
            Color(hex: 0xFF4D94),
            Color(hex: 0xFF7A45)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [Color(hex: 0xFFE07A), Color(hex: 0xFFA738)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Score scale — calm blue (low) → aura warm (high).
    static let scoreScale = LinearGradient(
        colors: [
            Color(hex: 0x4C8DFF),
            Color(hex: 0x8A5CFF),
            Color(hex: 0xFF4D94),
            Color(hex: 0xFFC23D)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Radii
    static let r12: CGFloat = 12
    static let r16: CGFloat = 16
    static let r22: CGFloat = 22

    /// Cool/calm for low scores, warm/celebratory for high.
    static func scoreColor(for value: Int) -> Color {
        switch value {
        case ..<40:  return blue
        case ..<60:  return teal
        case ..<75:  return violet
        case ..<90:  return pink
        default:     return gold
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Reusable visual modifiers

/// Soft warm bloom around primary actions and hero numbers.
struct AuraGlow: ViewModifier {
    var color: Color = Theme.pink
    var radius: CGFloat = 16
    var intensity: Double = 0.35

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity), radius: radius, y: 0)
            .shadow(color: color.opacity(intensity * 0.55), radius: radius * 1.9, y: 0)
    }
}

extension View {
    func auraGlow(color: Color = Theme.pink, radius: CGFloat = 16, intensity: Double = 0.35) -> some View {
        modifier(AuraGlow(color: color, radius: radius, intensity: intensity))
    }
}
