import SwiftUI

/// Charmster design tokens. Dark-first, near-black with violet tint + Aura gradient reward layer.
enum Theme {
    // Surfaces
    static let background = Color(hex: 0x0B0910)
    static let surface    = Color(hex: 0x14111C)
    static let elevated   = Color(hex: 0x1D1928)
    static let border     = Color(hex: 0x2C2740)

    // Text
    static let textPrimary   = Color(hex: 0xF6F4FA)
    static let textSecondary = Color(hex: 0xABA4BD)
    static let textMuted     = Color(hex: 0x6C6580)

    // Signature Aura gradient (purple -> pink -> red -> orange -> gold)
    static let auraColors: [Color] = [
        Color(hex: 0xA24BFF), Color(hex: 0xFF4D94),
        Color(hex: 0xFF3B5E), Color(hex: 0xFF7A45),
        Color(hex: 0xFFC23D)
    ]
    static let aura = LinearGradient(
        colors: auraColors,
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Score scale (cool -> warm) for gauges
    static let scoreColors: [Color] = [
        Color(hex: 0x4C8DFF), Color(hex: 0x8A5CFF),
        Color(hex: 0xFF4D94), Color(hex: 0xFFC23D)
    ]
    static let scoreScale = LinearGradient(
        colors: scoreColors,
        startPoint: .leading, endPoint: .trailing
    )

    // Semantic
    static let calmBlue = Color(hex: 0x4C8DFF) // low scores + info
    static let teal     = Color(hex: 0x35D6C5) // neutral success
    static let alertRed = Color(hex: 0xFF6B6B) // true errors only
    static let ember    = Color(hex: 0xFF7A45)
    static let gold     = Color(hex: 0xFFC23D)
    static let pink     = Color(hex: 0xFF4D94)
    static let purple   = Color(hex: 0xA24BFF)

    static let auraGlow = Color(hex: 0xFF4D94).opacity(0.35)

    // Score band color for a 0–100 score.
    static func scoreColor(_ s: Int) -> Color {
        switch s {
        case ..<40: return calmBlue
        case ..<60: return Color(hex: 0x8A5CFF)
        case ..<75: return pink
        case ..<90: return ember
        default:    return gold
        }
    }

    static func scoreBand(_ s: Int) -> String {
        switch s {
        case 90...: return "Magnetic"
        case 75...: return "Strong"
        case 60...: return "Warming up"
        case 40...: return "Friendly-neutral"
        default:    return "Off-track"
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
