import SwiftUI

enum Theme {
    // Palette
    static let background = Color(hex: 0x0D0D0D)
    static let surface = Color(hex: 0x1A1A1A)
    static let surfaceElevated = Color(hex: 0x222222)
    static let border = Color(hex: 0x2A2A2A)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0xA0A0A0)
    static let textTertiary = Color(hex: 0x666666)

    static let accent = Color(hex: 0x00E676)        // emerald — XP, CTA, progress
    static let accentDim = Color(hex: 0x00E676).opacity(0.15)
    static let coral = Color(hex: 0xFF5E62)         // boss fight, streak, urgency
    static let coralDim = Color(hex: 0xFF5E62).opacity(0.15)
    static let pathBlue = Color(hex: 0x4DA3FF)
    static let pathGold = Color(hex: 0xFFC857)

    // Radii
    static let rSmall: CGFloat = 10
    static let rMed: CGFloat = 16
    static let rLarge: CGFloat = 22

    // Spacing
    static let spacing: CGFloat = 16
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Typography
extension Font {
    static let displayXL = Font.system(size: 40, weight: .heavy, design: .rounded)
    static let displayL = Font.system(size: 32, weight: .bold, design: .rounded)
    static let titleXL = Font.system(size: 26, weight: .bold, design: .rounded)
    static let titleL = Font.system(size: 22, weight: .bold, design: .rounded)
    static let titleM = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let bodyM = Font.system(size: 16, weight: .regular)
    static let bodyS = Font.system(size: 14, weight: .regular)
    static let labelBold = Font.system(size: 14, weight: .bold, design: .rounded)
    static let monoNum = Font.system(size: 16, weight: .bold, design: .monospaced)
}
