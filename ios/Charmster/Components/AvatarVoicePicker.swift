import SwiftUI

/// Reusable VOICE picker for the AI practice partner. Lists the 5 voices by
/// their VIBE name (never an avatar name), each with a play/pause preview
/// button. Only ONE preview plays at a time; playback stops when the view is
/// dismissed. Selected = Aura border + checkmark.
///
/// Decoupled from the look: this writes only `app.profile.avatarVoiceId`, so any
/// voice pairs with any avatar look. Persists via the binding's `onChange`
/// callback. Adding a voice later is data-only (`AvatarVoice.library`).
struct AvatarVoicePicker: View {
  /// Currently-selected voice id.
  @Binding var selectedId: String
  /// Called after the selection changes so the caller can persist + react.
  var onChange: (String) -> Void = { _ in }

  @State private var player = AvatarVoicePreviewPlayer()

  var body: some View {
    VStack(spacing: 10) {
      ForEach(AvatarVoice.library) { voice in
        row(voice)
      }
      disclosure
    }
    .onDisappear { player.stop() }
  }

  private func row(_ voice: AvatarVoice) -> some View {
    let selected = selectedId == voice.id
    let playing = player.playingId == voice.id
    let failed = player.failedIds.contains(voice.id)

    return Button {
      #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      #endif
      if selectedId != voice.id {
        selectedId = voice.id
        onChange(voice.id)
      }
    } label: {
      HStack(spacing: 12) {
        // Play / pause preview.
        Button {
          player.toggle(voice)
        } label: {
          ZStack {
            Circle()
              .fill(playing ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surface))
              .frame(width: 40, height: 40)
            Image(
              systemName: failed ? "speaker.slash.fill" : (playing ? "pause.fill" : "play.fill")
            )
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(playing ? Theme.bg : (failed ? Theme.textFaint : Theme.text))
          }
          .overlay(
            Circle().strokeBorder(Theme.border, lineWidth: playing ? 0 : 1)
          )
        }
        .buttonStyle(.plain)
        .disabled(failed)

        VStack(alignment: .leading, spacing: 2) {
          Text(voice.displayName)
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(Theme.text)
          Text(failed ? "Preview unavailable" : (playing ? "Playing preview…" : "Tap play to hear"))
            .font(.system(size: 12))
            .foregroundStyle(Theme.textFaint)
        }

        Spacer()

        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22))
          .foregroundStyle(selected ? Theme.accent : Theme.textFaint)
      }
      .padding(14)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(Theme.surfaceRaised)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(
            selected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.border),
            lineWidth: selected ? 2.5 : 1)
      )
    }
    .buttonStyle(.plain)
  }

  private var disclosure: some View {
    HStack(spacing: 6) {
      Image(systemName: "waveform")
        .font(.system(size: 12))
      Text("This is an AI voice for practice — not a real person.")
        .font(.system(size: 12))
    }
    .foregroundStyle(Theme.textFaint)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 2)
  }
}
