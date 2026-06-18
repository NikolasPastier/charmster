import SwiftUI

/// The Aura lecture "stage": a soft pink→gold radial glow HALO rendered behind
/// the coach, with the coach clip played full-bleed but feathered into the dark
/// background via a soft elliptical alpha mask + vignette so its edges melt away
/// — never a hard rectangular video edge. Matches the approved Aura mockups.
///
/// Reuses `CoachAvatarView` (clip player + force-mute + still fallback) as the
/// single source of coach visuals; this view only adds the glow + feathering.
struct AuraCoachStage: View {
  let coach: CoachPersona
  /// Drives the talking vs idle loop.
  var speaking: Bool
  /// 1-based talking take, chosen once per lecture and held throughout.
  var talkingTake: Int = 1
  /// Smaller, dimmer treatment for picture-in-picture (non-avatar beats).
  var compact: Bool = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      // Aura glow halo BEHIND the coach — pink blending to gold, heavily
      // blurred, low opacity, darkening to near-black at the edges.
      auraHalo

      // Coach clip, full-bleed, feathered into the scene.
      CoachAvatarView(
        coach: coach,
        baseState: speaking ? .talking : .idle,
        talkingTake: talkingTake
      )
      .mask(featherMask)
      .overlay(vignette)
      .animation(.easeInOut(duration: 0.3), value: speaking)
    }
    .clipped()
  }

  // MARK: - Aura halo

  private var auraHalo: some View {
    let alpha: Double = compact ? 0.32 : 0.5
    return ZStack {
      RadialGradient(
        colors: [
          Theme.pink.opacity(alpha),
          Theme.gold.opacity(alpha * 0.6),
          .clear,
        ],
        center: .center,
        startRadius: compact ? 8 : 24,
        endRadius: compact ? 200 : 360
      )
      .blur(radius: compact ? 44 : 80)
      .scaleEffect(reduceMotion ? 1.0 : 1.02)
    }
    .allowsHitTesting(false)
  }

  // MARK: - Feathered alpha mask

  /// A soft elliptical alpha mask: fully opaque in the center, fading to clear
  /// toward the edges so the rectangular video frame melts into the background.
  private var featherMask: some View {
    GeometryReader { geo in
      RadialGradient(
        colors: [
          .black,
          .black.opacity(0.96),
          .black.opacity(0.45),
          .clear,
        ],
        center: .center,
        startRadius: 0,
        endRadius: max(geo.size.width, geo.size.height) * (compact ? 0.62 : 0.58)
      )
      .scaleEffect(x: 1.0, y: 1.18, anchor: .center)  // taller ellipse for a face
    }
  }

  /// A darkening vignette layered over the feathered clip so the edges read as
  /// near-black, exactly like the preview.
  private var vignette: some View {
    GeometryReader { geo in
      RadialGradient(
        colors: [
          .clear,
          .clear,
          Theme.bg.opacity(0.55),
          Theme.bg.opacity(0.95),
        ],
        center: .center,
        startRadius: 0,
        endRadius: max(geo.size.width, geo.size.height) * 0.62
      )
      .scaleEffect(x: 1.0, y: 1.2, anchor: .center)
      .blendMode(.normal)
      .allowsHitTesting(false)
    }
  }
}

#Preview {
  ZStack {
    Theme.bg.ignoresSafeArea()
    AuraCoachStage(coach: .default, speaking: true)
      .frame(height: 460)
  }
}
