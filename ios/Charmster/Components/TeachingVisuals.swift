import SwiftUI

// MARK: - Reusable teaching visuals
//
// Aura-styled, signaling-first contrast visuals for the GoodVsBad beat. The
// frame picks the right inner view by `ConversationMode`:
//   • inPerson → SpokenLineCard (quoted lines said OUT LOUD, voice-wave icon +
//     optional "how she'd feel" tag). NOT a messaging UI.
//   • texting  → ChatMockupCard (chat-bubble style).
// Every visual teaches — no decoration that doesn't carry meaning.

// MARK: - Good/Bad contrast frame

struct GoodBadContrastFrame: View {
  let mode: ConversationMode
  let good: ContrastExample
  let bad: ContrastExample

  var body: some View {
    VStack(spacing: 14) {
      slot(label: "GOOD", tone: Theme.good, example: good, isGood: true)
      Image(systemName: "arrow.down")
        .font(.system(size: 13, weight: .heavy))
        .foregroundStyle(Theme.textFaint)
      slot(label: "AVOID", tone: Theme.bad, example: bad, isGood: false)
    }
  }

  @ViewBuilder
  private func slot(label: String, tone: Color, example: ContrastExample, isGood: Bool)
    -> some View
  {
    switch mode {
    case .inPerson:
      SpokenLineCard(label: label, tone: tone, example: example, isGood: isGood)
    case .texting:
      ChatMockupCard(label: label, tone: tone, example: example, isGood: isGood)
    }
  }
}

// MARK: - SpokenLineCard (in-person)

/// A line said OUT LOUD — voice/sound-wave icon, the quoted line, and an
/// optional "how she'd feel" reaction tag. Deliberately NOT a chat bubble.
struct SpokenLineCard: View {
  let label: String
  let tone: Color
  let example: ContrastExample
  let isGood: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "waveform")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(tone)
        Text(label)
          .font(.system(size: 11, weight: .heavy)).tracking(1.6)
          .foregroundStyle(tone)
        Spacer()
        Image(systemName: isGood ? "checkmark.circle.fill" : "xmark.circle.fill")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(tone.opacity(0.8))
      }

      // The quoted spoken line, styled like speech (not a message bubble).
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: "quote.opening")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(tone.opacity(0.6))
        Text(example.line)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Theme.text)
          .fixedSize(horizontal: false, vertical: true)
      }

      if let tag = example.reactionTag {
        HStack(spacing: 6) {
          Image(systemName: "heart.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tone)
          Text(tag)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tone)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(tone.opacity(0.12)))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
        .fill(tone.opacity(0.08))
    )
    .overlay(
      RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
        .stroke(tone.opacity(0.35), lineWidth: 1)
    )
  }
}

// MARK: - ChatMockupCard (texting)

/// A messaging mockup — chat bubbles for texting lectures. Outgoing message is
/// the "you" bubble; the small status line signals the outcome.
struct ChatMockupCard: View {
  let label: String
  let tone: Color
  let example: ContrastExample
  let isGood: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "bubble.left.and.bubble.right.fill")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(tone)
        Text(label)
          .font(.system(size: 11, weight: .heavy)).tracking(1.6)
          .foregroundStyle(tone)
        Spacer()
        Image(systemName: isGood ? "checkmark.circle.fill" : "xmark.circle.fill")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(tone.opacity(0.8))
      }

      // Outgoing chat bubble (right-aligned).
      HStack {
        Spacer(minLength: 36)
        Text(example.line)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 14).padding(.vertical, 10)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(isGood ? Theme.accentGradient : badBubble)
          )
      }

      Text(isGood ? "Delivered · she's typing…" : "Delivered · read, no reply")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Theme.textFaint)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
        .fill(Theme.surfaceRaised)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
        .stroke(tone.opacity(0.3), lineWidth: 1)
    )
  }

  private var badBubble: LinearGradient {
    LinearGradient(
      colors: [Theme.bad.opacity(0.85), Theme.bad.opacity(0.6)],
      startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}

// MARK: - Insight contrast cards (signaling the single key phrase)

/// Lightweight emphasis visual for the CoreInsight beat — a single highlighted
/// key phrase with supporting "two-of-three" style chips. No good/bad here.
struct InsightSignalCard: View {
  let signalPhrase: String
  let supporting: [String]

  var body: some View {
    VStack(spacing: 16) {
      Text(signalPhrase)
        .font(.system(size: 30, weight: .heavy))
        .multilineTextAlignment(.center)
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
          Rectangle()
            .fill(Theme.accentGradient)
            .frame(height: 4)
            .offset(y: 10)
            .opacity(0.8)
        }
      if !supporting.isEmpty {
        HStack(spacing: 8) {
          ForEach(supporting, id: \.self) { chip in
            Text(chip)
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(Theme.textMuted)
              .padding(.horizontal, 12).padding(.vertical, 7)
              .background(Capsule().fill(Theme.surfaceRaised))
              .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
          }
        }
        .padding(.top, 6)
      }
    }
  }
}

#Preview("Spoken vs Chat") {
  ZStack {
    Theme.bg.ignoresSafeArea()
    ScrollView {
      VStack(spacing: 22) {
        GoodBadContrastFrame(
          mode: .inPerson,
          good: ContrastExample(
            line: "That book looks better than mine. Sell me.", reactionTag: "She leans in"),
          bad: ContrastExample(
            line: "Hey so what do you do?", reactionTag: "She checks out"))
        GoodBadContrastFrame(
          mode: .texting,
          good: ContrastExample(line: "You'd hate the playlist I'm on right now", reactionTag: nil),
          bad: ContrastExample(line: "hey", reactionTag: nil))
        InsightSignalCard(signalPhrase: "Two of three", supporting: ["Voice", "Eyes", "Timing"])
      }
      .padding(18)
    }
  }
}
