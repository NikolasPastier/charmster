import SwiftUI

/// UX5 — the intro "What you'll learn" card (Card 0) shown before Beat 1.
///
/// Audio-first discipline still applies: this is a quiet, minimal preview of
/// 2–3 outcomes — never a paragraph. It uses the Aura palette and a soft
/// staged entrance so it feels like the opening beat of the story, then hands
/// straight into the Hook. Long objective strings wrap to a max of two lines
/// and scale down gracefully.
struct LectureObjectivesCard: View {
  let objectives: [String]
  /// Changes per lecture so the staged entrance plays once on appear.
  var replayToken: AnyHashable

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = false

  private var items: [String] { Array(objectives.prefix(3)) }

  var body: some View {
    VStack(spacing: 22) {
      Spacer(minLength: 0)

      VStack(spacing: 8) {
        Image(systemName: "sparkles")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(Theme.aura)
        Text("By the end, you'll be able to:")
          .font(.system(size: 21, weight: .heavy))
          .multilineTextAlignment(.center)
          .foregroundStyle(Theme.text)
          .padding(.horizontal, 20)
      }
      .opacity(shown ? 1 : 0)
      .offset(y: shown || reduceMotion ? 0 : 10)

      VStack(alignment: .leading, spacing: 14) {
        ForEach(Array(items.enumerated()), id: \.offset) { i, line in
          objectiveRow(line, index: i)
        }
      }
      .padding(.horizontal, 20)

      Text("You'll practice this next.")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.textFaint)
        .opacity(shown ? 1 : 0)

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear { play() }
    .onChange(of: replayToken) { _, _ in
      shown = false
      play()
    }
  }

  @ViewBuilder
  private func objectiveRow(_ line: String, index i: Int) -> some View {
    let visible = shown
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(Theme.accent)
      Text(line)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Theme.text)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Theme.surface.opacity(0.7))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(Theme.border, lineWidth: 1)
    )
    .opacity(visible ? 1 : 0)
    .offset(y: visible || reduceMotion ? 0 : 14)
    .animation(
      reduceMotion
        ? .easeOut(duration: 0.2)
        : .spring(response: 0.5, dampingFraction: 0.82).delay(0.08 * Double(i) + 0.1),
      value: shown)
  }

  private func play() {
    if reduceMotion {
      withAnimation(.easeOut(duration: 0.2)) { shown = true }
    } else {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { shown = true }
    }
  }
}

#Preview {
  ZStack {
    Theme.bg.ignoresSafeArea()
    LectureObjectivesCard(
      objectives: [
        "Open with one true line that earns a real reply",
        "Say a clean, specific opener out loud",
        "Avoid the survey-style question opener",
      ],
      replayToken: 0
    )
  }
}
