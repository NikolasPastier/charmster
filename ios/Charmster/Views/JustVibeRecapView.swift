import SwiftUI

/// Post-session recap for Just Vibe (unscored) sandbox sessions.
/// Shows warmth + duration only — no score ring, no dimensions, no Aura badge.
struct JustVibeRecapView: View {
  @Environment(AppState.self) private var app
  let result: SessionResult
  let onAgain: () -> Void
  let onDone: () -> Void

  private var durationMinutes: Int { max(1, result.durationSeconds / 60) }

  var body: some View {
    ZStack {
      AuraBackground()
      ScrollView {
        VStack(spacing: 24) {
          Spacer(minLength: 40)

          Image(systemName: "waveform.circle.fill")
            .font(.system(size: 64, weight: .ultraLight))
            .foregroundStyle(Theme.accent)

          VStack(spacing: 8) {
            Text("Good session.")
              .font(.system(size: 30, weight: .heavy))
              .foregroundStyle(Theme.text)
            Text("You practiced for \(durationMinutes) minute\(durationMinutes == 1 ? "" : "s").")
              .font(.system(size: 16))
              .foregroundStyle(Theme.textMuted)
          }

          if result.streakKept {
            GlassCard {
              HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(Theme.coral)
                VStack(alignment: .leading, spacing: 2) {
                  Text("Streak kept")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.text)
                  Text("\(app.streakDays) day\(app.streakDays == 1 ? "" : "s") and counting.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                }
                Spacer()
              }
            }
            .padding(.horizontal, 18)
          }

          Spacer(minLength: 8)

          VStack(spacing: 10) {
            AuraButton(title: "Practice again", systemImage: "arrow.counterclockwise", action: onAgain)
            GlassButton(title: "Done", systemImage: "checkmark", action: onDone)
          }
          .padding(.horizontal, 18)
          .padding(.bottom, 32)
        }
      }
    }
    .trackView("JustVibeRecapView")
  }
}

#Preview {
  JustVibeRecapView(
    result: SessionResult(
      id: UUID(), lectureId: nil, isCapstone: false, isSandbox: true,
      responsiveness: 70, voice: 68, face: 0, body: 0,
      synchrony: 65, calibration: 60, comfort: 72,
      sessionScore: 0, auraEarned: 0,
      streakKept: true, coinsEarned: 0, durationSeconds: 210,
      safetyCapApplied: false, createdAt: .now
    ),
    onAgain: {}, onDone: {}
  )
  .environment(AppState.preview)
}
