import SwiftUI

/// Centralized design tokens for Charmster. Dark, premium, content-forward.
enum Theme {
    // MARK: - Base palette
    static let bg            = Color(hex: 0x0D0D0D)
    static let surface       = Color(hex: 0x1A1A1A)
    static let surfaceRaised = Color(hex: 0x222222)
    static let border        = Color(hex: 0x2A2A2A)
    static let divider       = Color(hex: 0x222626)

    // MARK: - Type
    static let text          = Color.white.opacity(0.92)
    static let textMuted     = Color.white.opacity(0.6)
    static let textFaint     = Color.white.opacity(0.4)

    // MARK: - Accents
    static let accent        = Color(hex: 0x00E676) // emerald — XP / CTA / progress
    static let accentDim     = Color(hex: 0x00B85A)
    static let coral         = Color(hex: 0xFF5E62) // boss / streak / urgency
    static let teal          = Color(hex: 0x4DD0E1)
    static let gold          = Color(hex: 0xFFC857) // capstones
    static let aura          = Color(hex: 0xFF7A8A) // brand aura halo
    static let auraGlow      = Color(hex: 0xFF4D6D)

    // MARK: - Semantic
    static let good          = Color(hex: 0x4ADE80)
    static let warn          = Color(hex: 0xFBBF24)
    static let bad           = Color(hex: 0xF87171)

    // MARK: - Gradients
    static let auraGradient = LinearGradient(
        colors: [aura, auraGlow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let goldGradient = LinearGradient(
        colors: [Color(hex: 0xFFE07A), Color(hex: 0xFFA738)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let accentGradient = LinearGradient(
        colors: [accent, accentDim],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Radii
    static let r12: CGFloat = 12
    static let r16: CGFloat = 16
    static let r22: CGFloat = 22
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
