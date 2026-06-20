import SwiftUI

/// The Aura lecture "stage": a reactive pink→gold halo behind the coach,
/// expression stills swapping per beat with a feathered alpha mask + vignette
/// so the portrait edges melt into the dark background.
///
/// Expression stills (from `CoachExpressionStore`) are the primary visual.
/// `CoachAvatarView` (video clip) sits underneath and shows through while stills
/// are loading — clips only ever enhance, never block.
struct AuraCoachStage: View {
  let coach: CoachPersona
  var speaking: Bool
  var talkingTake: Int = 1
  var compact: Bool = false
  /// Beat-driven expression. Changes trigger a debounced cross-dissolve swap.
  var expression: ExpressionPose = .neutral

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // Reactive halo
  @State private var glowScale: Double = 1.0

  // Expression double-buffer cross-dissolve
  @State private var frontPose: ExpressionPose = .neutral
  @State private var backPose: ExpressionPose = .neutral
  @State private var frontOpacity: Double = 1.0
  @State private var lastSwap: Date = .distantPast

  // Ken Burns slow drift on the front still
  @State private var drift: Double = 0

  var body: some View {
    ZStack {
      auraHalo

      ZStack {
        // Video fallback — shows through while expression stills are loading
        CoachAvatarView(
          coach: coach,
          baseState: speaking ? .talking : .idle,
          talkingTake: talkingTake
        )

        // Back still fades out during cross-dissolve
        expressionLayer(pose: backPose)
          .opacity(1.0 - frontOpacity)

        // Front still fades in; Ken Burns drift when not in reduced-motion
        expressionLayer(pose: frontPose)
          .opacity(frontOpacity)
          .scaleEffect(reduceMotion ? 1.0 : 1.01 + 0.02 * drift, anchor: .top)
      }
      .mask(featherMask)
      .overlay(vignette)
      .animation(.easeInOut(duration: 0.3), value: speaking)
    }
    .clipped()
    .onAppear {
      frontPose = expression
      backPose = expression
      lastSwap = Date()
      guard !reduceMotion else { return }
      // Breathing idle on glow
      withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
        glowScale = 1.05
      }
      // Slow Ken Burns drift on front still
      withAnimation(.linear(duration: 28.0).repeatForever(autoreverses: true)) {
        drift = 1.0
      }
    }
    .onChange(of: speaking) { _, isSpeaking in
      guard !reduceMotion else { return }
      // Pulse while narrating; slow-breathe when idle
      withAnimation(
        .easeInOut(duration: isSpeaking ? 1.2 : 4.0).repeatForever(autoreverses: true)
      ) {
        glowScale = isSpeaking ? 1.10 : 1.05
      }
    }
    .onChange(of: expression) { _, newPose in
      // Debounce: minimum 1.2 s between swaps
      let now = Date()
      guard now.timeIntervalSince(lastSwap) >= 1.2 else { return }
      lastSwap = now
      backPose = frontPose
      frontPose = newPose
      frontOpacity = 0.0
      withAnimation(.easeInOut(duration: 0.22)) { frontOpacity = 1.0 }
    }
  }

  // MARK: - Reactive Aura halo

  private var auraHalo: some View {
    let alpha: Double = compact ? 0.32 : 0.5
    return RadialGradient(
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
    .scaleEffect(glowScale)
    .allowsHitTesting(false)
  }

  // MARK: - Expression still

  @ViewBuilder
  private func expressionLayer(pose: ExpressionPose) -> some View {
    AsyncImage(url: CoachExpressionStore.shared.url(for: coach.id, pose: pose)) { image in
      image.resizable().scaledToFill()
    } placeholder: {
      Color.clear
    }
  }

  // MARK: - Feathered alpha mask

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
      .scaleEffect(x: 1.0, y: 1.18, anchor: .center)
    }
  }

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
    AuraCoachStage(coach: .default, speaking: true, expression: .intrigued)
      .frame(height: 460)
  }
}
