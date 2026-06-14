import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// Centralized design tokens for Charmster.
/// Dark, cinematic, premium "noir-tech" base lit by a warm love-spectrum gradient.
enum Theme {
  // MARK: - Base neutrals (adaptive: warm near-white in Light, noir-violet in Dark)
  //
  // Dark values are the original Charmster palette (unchanged so the dark UI is
  // byte-identical). Light values are a warm, low-glare near-white set tuned for
  // contrast against the brand accents. Because these are dynamic colors, the
  // single root `.preferredColorScheme` re-skins ALL tabs — including the custom
  // token-painted ones — not just native chrome.
  static let bg = Color(lightHex: 0xFAF7FB, darkHex: 0x0B0910)  // app background
  static let surface = Color(lightHex: 0xFFFFFF, darkHex: 0x14111C)  // cards, sheets, tab bar
  static let surfaceRaised = Color(lightHex: 0xF1ECF5, darkHex: 0x1D1928)  // elevated tiles
  static let border = Color(lightHex: 0xE6DEEE, darkHex: 0x2C2740)  // strokes / dividers
  static let divider = Color(lightHex: 0xE6DEEE, darkHex: 0x2C2740)

  // MARK: - Type
  static let text = Color(lightHex: 0x1A1622, darkHex: 0xF6F4FA)
  static let textMuted = Color(lightHex: 0x6B6479, darkHex: 0xABA4BD)
  static let textFaint = Color(lightHex: 0xA59CB4, darkHex: 0x6C6580)  // hints, disabled, locked

  // MARK: - Love spectrum (warm accents)
  static let purple = Color(hex: 0xA24BFF)
  static let pink = Color(hex: 0xFF4D94)  // PRIMARY brand
  static let red = Color(hex: 0xFF3B5E)
  static let orange = Color(hex: 0xFF7A45)
  static let gold = Color(hex: 0xFFC23D)

  // MARK: - Cool feedback (calm, "room to grow")
  static let blue = Color(hex: 0x4C8DFF)
  static let teal = Color(hex: 0x35D6C5)
  static let violet = Color(hex: 0x8A5CFF)

  // MARK: - Semantic aliases (kept for existing call sites)
  static let accent = pink  // brand / CTA / progress
  static let accentDim = purple
  static let coral = red  // boss / streak / urgency
  static let xp = gold  // XP chips
  static let aura = pink  // brand aura halo
  static let auraGlow = red

  // MARK: - Semantic states
  static let good = teal
  static let warn = gold
  static let bad = Color(hex: 0xFF6B6B)  // true-error red (separate from celebratory brand red)

  // MARK: - Signature gradients
  /// Aura — the full love spectrum. topLeading → bottomTrailing.
  static let auraGradient = LinearGradient(
    colors: [
      Color(hex: 0xA24BFF),
      Color(hex: 0xFF4D94),
      Color(hex: 0xFF3B5E),
      Color(hex: 0xFF7A45),
      Color(hex: 0xFFC23D),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  /// Primary CTA gradient — a warm slice of the aura.
  static let accentGradient = LinearGradient(
    colors: [
      Color(hex: 0xA24BFF),
      Color(hex: 0xFF4D94),
      Color(hex: 0xFF7A45),
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
      Color(hex: 0xFFC23D),
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
    case ..<40: return blue
    case ..<60: return teal
    case ..<75: return violet
    case ..<90: return pink
    default: return gold
    }
  }
}

extension Color {
  init(hex: UInt32, alpha: Double = 1.0) {
    let r = Double((hex >> 16) & 0xFF) / 255.0
    let g = Double((hex >> 8) & 0xFF) / 255.0
    let b = Double(hex & 0xFF) / 255.0
    self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
  }

  /// Adaptive color that resolves per trait collection. Drives Light/Dark
  /// re-skin across every Theme token from the single root color scheme.
  init(lightHex: UInt32, darkHex: UInt32, alpha: Double = 1.0) {
    #if canImport(UIKit)
      self.init(
        UIColor { traits in
          let hex = traits.userInterfaceStyle == .dark ? darkHex : lightHex
          let r = CGFloat((hex >> 16) & 0xFF) / 255.0
          let g = CGFloat((hex >> 8) & 0xFF) / 255.0
          let b = CGFloat(hex & 0xFF) / 255.0
          return UIColor(red: r, green: g, blue: b, alpha: CGFloat(alpha))
        })
    #else
      self.init(hex: lightHex, alpha: alpha)
    #endif
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
  func auraGlow(color: Color = Theme.pink, radius: CGFloat = 16, intensity: Double = 0.35)
    -> some View
  {
    modifier(AuraGlow(color: color, radius: radius, intensity: intensity))
  }
}
