import SwiftUI

/// FX9.6 / UX4 — optional Duolingo-style coach "pop-in" moment.
///
/// A small picture-in-picture coach bubble that slides/peeks in for character
/// flavor on select beats (by default only the Hook and Takeaway). It adds NO
/// new narration — the audio is the only voice. An optional one-line micro-text
/// (3–7 words) may show, but it must never duplicate narration.
///
/// Reuses `AuraCoachStage` (compact) as the single source of coach visuals.
/// Under Reduce Motion the slide/peek is replaced by a simple fade.
struct CoachPopInOverlay: View {
  enum Placement {
    case bottomLeading
    case bottomTrailing
  }

  let coach: CoachPersona
  var placement: Placement = .bottomLeading
  /// Optional 1-line micro-text (3–7 words). Keep it flavorful, NOT narration.
  var message: String? = nil
  var talkingTake: Int = 1
  /// Changes per beat so the pop-in plays once per appearance.
  var replayToken: AnyHashable

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = false

  var body: some View {
    HStack(spacing: 10) {
      if placement == .bottomTrailing { Spacer() }
      bubble
      if placement == .bottomLeading { Spacer() }
    }
    .padding(.horizontal, 18)
    .padding(.bottom, 6)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .allowsHitTesting(false)
    .onAppear { play() }
    .onChange(of: replayToken) { _, _ in
      shown = false
      play()
    }
  }

  private var bubble: some View {
    HStack(spacing: 10) {
      AuraCoachStage(coach: coach, speaking: false, talkingTake: talkingTake, compact: true)
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.border, lineWidth: 1))

      if let message {
        Text(message)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(Theme.text)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .padding(.trailing, 6)
      }
    }
    .padding(6)
    .background(
      Capsule().fill(Theme.surfaceRaised.opacity(message == nil ? 0.0 : 0.9))
    )
    .overlay(
      message == nil ? nil : Capsule().stroke(Theme.border, lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.3), radius: 10, y: 3)
    .opacity(shown ? 1 : 0)
    .scaleEffect(reduceMotion ? 1.0 : (shown ? 1.0 : 0.85), anchor: .bottomLeading)
    .offset(y: shown || reduceMotion ? 0 : 26)
    .offset(x: offsetX)
  }

  private var offsetX: CGFloat {
    guard !reduceMotion, !shown else { return 0 }
    // -14 keeps the bubble within the 18pt horizontal padding at its start position,
    // preventing the left-edge clip that -24 caused (18 - 14 = 4pt on screen).
    return placement == .bottomLeading ? -14 : 14
  }

  private func play() {
    let delay = 0.45  // let the key point land first
    if reduceMotion {
      withAnimation(.easeIn(duration: 0.2).delay(delay)) { shown = true }
    } else {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
        shown = true
      }
    }
  }
}

#Preview {
  ZStack {
    Theme.bg.ignoresSafeArea()
    CoachPopInOverlay(coach: .default, message: "Let's get into it", replayToken: 0)
  }
}
