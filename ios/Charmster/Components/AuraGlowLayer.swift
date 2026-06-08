import SwiftUI

/// Reactive Aura glow rendered behind the avatar. A large blurred radial
/// gradient (pink -> gold -> transparent) on the dark base. Intensity + warmth
/// follow the live atmosphere score; a subtle pulse runs while the partner is
/// speaking. Reduced-motion holds the glow static.
struct AuraGlowLayer: View {
    /// 0..1 atmosphere score. Higher = warmer + brighter.
    let intensity: Double
    /// Pulse while the partner speaks.
    let partnerSpeaking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: Double = 0

    var body: some View {
        let warmth = max(0, min(1, intensity))
        let scale: Double = reduceMotion ? 1.0 : (1.0 + 0.06 * pulse)
        let alpha: Double = 0.30 + 0.45 * warmth

        ZStack {
            Theme.bg.ignoresSafeArea()

            RadialGradient(
                colors: [
                    Theme.pink.opacity(alpha),
                    Theme.gold.opacity(alpha * 0.55),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 460
            )
            .blur(radius: 80)
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 0.6), value: warmth)

            RadialGradient(
                colors: [
                    Theme.violet.opacity(0.25 * (1 - warmth)),
                    .clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 520
            )
            .blur(radius: 100)
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear { if !reduceMotion { startPulse() } }
        .onChange(of: partnerSpeaking) { _, speaking in
            guard !reduceMotion else { return }
            if speaking { startPulse() } else { stopPulse() }
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulse = 1
        }
    }

    private func stopPulse() {
        withAnimation(.easeInOut(duration: 0.8)) { pulse = 0 }
    }
}
