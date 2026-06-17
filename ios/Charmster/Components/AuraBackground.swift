import SwiftUI

/// Reusable cinematic background for Charmster's primary surfaces. A deep
/// `Theme.bg` base lit by a soft plum→pink→gold aura glow anchored top-trailing,
/// with a subtle dark vignette at the bottom for text contrast.
///
/// GPU-cheap by design: STATIC gradients, no continuous animation. Sits behind
/// content and ignores the safe area. Cards/sheets stay on `Theme.surface` so
/// content remains legible on top of the gradient.
///
/// Use the `calm` variant behind dense scrolling lists where a brighter glow
/// would hurt readability.
struct AuraBackground: View {
  /// Lower-opacity treatment for dense scrolling lists.
  var calm: Bool = false

  private var glowOpacity: Double { calm ? 0.16 : 0.26 }

  var body: some View {
    ZStack {
      Theme.bg

      // Plum → pink → gold aura glow, anchored top-trailing, heavily blurred.
      RadialGradient(
        colors: [
          Theme.purple.opacity(glowOpacity),
          Theme.pink.opacity(glowOpacity * 0.85),
          Theme.gold.opacity(glowOpacity * 0.45),
          .clear,
        ],
        center: UnitPoint(x: 0.82, y: 0.12),
        startRadius: 20,
        endRadius: 520
      )
      .blur(radius: 70)

      // Subtle bottom vignette for text contrast on lower content.
      LinearGradient(
        colors: [.clear, .clear, Theme.bg.opacity(0.65)],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }
}

// MARK: - App-themed color scheme (fixes white sheets/covers)

/// Resolve the user's Appearance preference into a `ColorScheme?`.
/// "dark" -> .dark, "light" -> .light, anything else ("system") -> nil.
///
/// `.sheet` and `.fullScreenCover` spawn their own presentation context and
/// fall back to the DEVICE appearance, so the root `.preferredColorScheme`
/// does NOT propagate into them. Apply `appThemedScheme(...)` to each presented
/// root so adaptive `Theme.*` tokens resolve to the app's chosen appearance.
func appThemedScheme(_ pref: String) -> ColorScheme? {
  switch pref {
  case "dark": return .dark
  case "light": return .light
  default: return nil  // "system"
  }
}

/// Attaches the app's chosen color scheme to a presented (sheet/cover) root so
/// it never falls back to the device appearance. Reads the preference from the
/// shared `AppState` in the environment.
private struct AppThemedSchemeModifier: ViewModifier {
  @Environment(AppState.self) private var app
  func body(content: Content) -> some View {
    content.preferredColorScheme(appThemedScheme(app.profile.themePreference))
  }
}

extension View {
  /// Force this presented root into the app's chosen Appearance. Use on the
  /// content of every `.sheet` and `.fullScreenCover`.
  func appThemedPresentation() -> some View {
    modifier(AppThemedSchemeModifier())
  }
}

#Preview {
  ZStack {
    AuraBackground()
    VStack(spacing: 12) {
      Text("Aura background")
        .font(.system(size: 24, weight: .heavy))
        .foregroundStyle(Theme.text)
      RoundedRectangle(cornerRadius: 16)
        .fill(Theme.surface)
        .frame(height: 120)
        .overlay(Text("Card on surface").foregroundStyle(Theme.text))
        .padding(.horizontal, 24)
    }
  }
}
