import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// FX9.6 / UX4 — Duolingo-style "key point" pop for the lecture story player.
///
/// Renders the beat's single signal phrase (NEVER the full narration) with a
/// premium pop + settle entrance and a subtle Aura highlight sweep behind it.
/// A very light impact haptic fires once when the phrase lands (respecting the
/// system Reduce Motion setting — under Reduce Motion the pop becomes a quiet
/// fade with a static highlight and no haptic).
///
/// Signaling discipline: the phrase is short by contract (2–6 words). Anything
/// longer wraps to a maximum of two lines; a very long phrase is split into two
/// staged pops (max 2 stages) so it never reads as a paragraph caption.
struct KeyPointPopView: View {
  let text: String
  /// Visual emphasis 0…1 — scales the highlight sweep intensity + glow.
  var emphasisLevel: Double = 1.0
  /// A token that changes per beat. When it changes the pop replays exactly
  /// once; identical values do NOT replay (pause/return stays calm).
  var replayToken: AnyHashable

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  // Two staged fragments (1 or 2). Most phrases are a single stage.
  private var stages: [String] { Self.split(text) }

  // Per-stage animation state.
  @State private var shown: [Bool] = []
  @State private var settled: [Bool] = []
  @State private var sweep: [Bool] = []
  @State private var didFire = false

  var body: some View {
    VStack(spacing: 6) {
      ForEach(Array(stages.enumerated()), id: \.offset) { i, fragment in
        stageView(fragment, index: i)
      }
    }
    .padding(.horizontal, 24)
    .onAppear { runIfNeeded(force: false) }
    .onChange(of: replayToken) { _, _ in runIfNeeded(force: true) }
  }

  // MARK: - Stage

  @ViewBuilder
  private func stageView(_ fragment: String, index i: Int) -> some View {
    let isShown = shown.indices.contains(i) && shown[i]
    let isSettled = settled.indices.contains(i) && settled[i]
    let isSweeping = sweep.indices.contains(i) && sweep[i]

    Text(fragment)
      .font(.system(size: 26, weight: .heavy))
      .multilineTextAlignment(.center)
      .lineLimit(2)
      .minimumScaleFactor(0.7)
      .foregroundStyle(Theme.text)
      .shadow(color: Color(hex: 0x0B0910).opacity(0.7), radius: 8, y: 2)
      .padding(.horizontal, 14)
      .padding(.vertical, 6)
      .background(highlight(active: isSweeping))
      .scaleEffect(scale(isShown: isShown, isSettled: isSettled))
      .opacity(isShown ? 1 : 0)
  }

  /// The Aura highlight bar that sweeps in behind the phrase.
  @ViewBuilder
  private func highlight(active: Bool) -> some View {
    let inset: CGFloat = reduceMotion ? 0 : (active ? 0 : 1)
    GeometryReader { geo in
      Capsule()
        .fill(Theme.auraGradient)
        .frame(
          width: reduceMotion ? geo.size.width : geo.size.width * (active ? 1 : 0.0),
          height: geo.size.height
        )
        .opacity(0.18 * emphasisLevel)
        .blur(radius: 6)
        .frame(width: geo.size.width, alignment: .leading)
        .padding(.vertical, inset)
    }
    .allowsHitTesting(false)
  }

  // MARK: - Geometry

  private func scale(isShown: Bool, isSettled: Bool) -> CGFloat {
    if reduceMotion { return 1.0 }
    if !isShown { return 0.92 }
    return isSettled ? 1.0 : 1.03
  }

  // MARK: - Run

  private func runIfNeeded(force: Bool) {
    if !force && !shown.isEmpty { return }
    prepareState()

    if reduceMotion {
      // Quiet fade, static highlight, no haptic, no overshoot.
      for i in stages.indices {
        withAnimation(.easeIn(duration: 0.18).delay(Double(i) * 0.12)) {
          shown[i] = true
          settled[i] = true
          sweep[i] = true
        }
      }
      return
    }

    for i in stages.indices {
      let base = Double(i) * 0.22  // stagger the second stage
      // Pop in with spring overshoot.
      withAnimation(
        .spring(response: 0.42, dampingFraction: 0.6).delay(base)
      ) {
        shown[i] = true
      }
      // Settle from 1.03 → 1.0.
      withAnimation(
        .spring(response: 0.34, dampingFraction: 0.82).delay(base + 0.16)
      ) {
        settled[i] = true
      }
      // Aura sweep behind the text.
      withAnimation(.easeOut(duration: 0.32).delay(base + 0.06)) {
        sweep[i] = true
      }
    }

    // Light impact haptic on the first landing only.
    fireHaptic()
  }

  private func prepareState() {
    let n = stages.count
    shown = Array(repeating: false, count: n)
    settled = Array(repeating: false, count: n)
    sweep = Array(repeating: false, count: n)
    didFire = false
  }

  private func fireHaptic() {
    guard !didFire, !reduceMotion else { return }
    didFire = true
    #if canImport(UIKit)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: 0.7)
      }
    #endif
  }

  // MARK: - Split

  /// Keep the phrase short. Single short phrases stay one stage; only an
  /// unusually long phrase (>~22 chars and 4+ words) splits near the middle
  /// word boundary into two stages. Hard cap: 2 stages.
  static func split(_ raw: String) -> [String] {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let words = text.split(separator: " ").map(String.init)
    guard text.count > 22, words.count >= 4 else { return [text] }
    let mid = words.count / 2
    let first = words[..<mid].joined(separator: " ")
    let second = words[mid...].joined(separator: " ")
    return [first, second]
  }
}

#Preview {
  ZStack {
    Theme.bg.ignoresSafeArea()
    KeyPointPopView(text: "First seconds matter", replayToken: 0)
  }
}
