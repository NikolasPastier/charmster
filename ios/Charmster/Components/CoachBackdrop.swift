import SwiftUI
import UIKit

/// FX9.6 — a soft "coach glowing behind the content" ambient backdrop.
///
/// Uses the coach's IDLE STILL (not live video): `.scaledToFill()`, heavily
/// blurred, clipped, full-bleed. This recreates the sketch's glow look WITHOUT
/// transparent/alpha video — the blur erases the rectangular video edge, so a
/// plain still is all that's needed. It's GPU-cheap (a single static blurred
/// image, no continuous animation) and works even before the coach clip
/// playback is fixed.
///
/// Tinted into the Aura palette: a plum→black vertical gradient keeps the sharp
/// foreground content legible on top. While the still loads (or offline) it
/// falls back to a calm Aura glow so it's never flat black.
struct CoachBackdrop: View {
  let coach: CoachPersona
  /// Blur strength for the still. Higher = softer/dreamier.
  var blur: CGFloat = 36

  @State private var still: UIImage?

  var body: some View {
    ZStack {
      // Base so the backdrop is never flat black before the still resolves.
      Theme.bg

      if let still {
        Image(uiImage: still)
          .resizable()
          .scaledToFill()
          .blur(radius: blur)
          .opacity(0.9)
          .transition(.opacity)
      } else {
        // Aura glow fallback while the still downloads / when offline.
        RadialGradient(
          colors: [
            Theme.purple.opacity(0.45),
            Theme.pink.opacity(0.30),
            .clear,
          ],
          center: UnitPoint(x: 0.5, y: 0.34),
          startRadius: 20,
          endRadius: 460
        )
        .blur(radius: 70)
      }

      // Aura-palette tint for contrast + brand: plum at top, black at bottom so
      // the foreground text always stays legible over the glow.
      LinearGradient(
        colors: [
          Theme.purple.opacity(0.55),
          Theme.bg.opacity(0.45),
          Theme.bg.opacity(0.75),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .clipped()
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .animation(.easeInOut(duration: 0.4), value: still != nil)
    .task(id: coach.id) {
      still = await CoachClipCatalog.shared.idleStill(for: coach)
    }
  }
}

#Preview {
  ZStack {
    CoachBackdrop(coach: .default)
    Text("Sharp foreground content")
      .font(.system(size: 26, weight: .heavy))
      .foregroundStyle(Theme.text)
  }
}
