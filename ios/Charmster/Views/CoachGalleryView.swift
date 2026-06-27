import SwiftUI

/// "Meet your coaches" — the gallery + join flow. Used in onboarding (the
/// coach step) and re-openable from Profile/Settings. Selecting a coach JOINS
/// their team: one tap sets `selectedCoachId` (and keeps the legacy tone engine
/// in sync) and shows a short confirmation beat.
///
/// roleTag + shortDescription live HERE (a selection surface) only — the
/// in-game UI shows the human name alone.
struct CoachGalleryView: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss

  /// Onboarding embeds the gallery inline (no nav chrome) and drives its own
  /// Continue button; Settings/Profile present it as a dismissible screen.
  var embedded: Bool = false
  /// Called after a coach is joined (onboarding advances; sheets dismiss).
  var onJoined: (() -> Void)? = nil

  @State private var expanded: CoachPersona?
  @State private var justJoined: CoachPersona?
  @State private var previewPlayer = CoachPreviewPlayer()

  var body: some View {
    content
      .background { if !embedded { AuraBackground() } }
      .overlay(alignment: .center) {
        if let coach = justJoined {
          JoinConfirmation(coach: coach)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
      }
      .animation(.spring(response: 0.4, dampingFraction: 0.8), value: justJoined)
      .trackView("CoachGalleryView")
  }

  @ViewBuilder
  private var content: some View {
    if embedded {
      gallery
    } else {
      NavigationStack {
        ScrollView { gallery.padding(18) }
          .background(AuraBackground())
          .navigationTitle("Meet your coaches")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Done") { dismiss() }
            }
          }
      }
    }
  }

  private var gallery: some View {
    VStack(spacing: 14) {
      ForEach(CoachPersona.library) { coach in
        CoachCard(
          coach: coach,
          isCurrent: app.selectedCoachId == coach.id,
          isPreviewing: previewPlayer.isPlaying(coachId: coach.id),
          onJoin: { join(coach) }
        )
      }
    }
    .onDisappear { previewPlayer.stop() }
  }

  private func join(_ coach: CoachPersona) {
    // Auto-play the coach's three voice preview lines in order 1 -> 2 -> 3.
    previewPlayer.play(coach)
    app.joinCoach(coach)
    #if canImport(UIKit)
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    #endif
    justJoined = coach
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
      justJoined = nil
      onJoined?()
      if !embedded { dismiss() }
    }
  }
}

// MARK: - Coach card

private struct CoachCard: View {
  let coach: CoachPersona
  let isCurrent: Bool
  let isPreviewing: Bool
  let onJoin: () -> Void

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 14) {
          CoachAvatarView(coach: coach)
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(
              Circle().stroke(
                isPreviewing ? Theme.accent : Theme.border,
                lineWidth: isPreviewing ? 2 : 1)
            )
            .overlay(alignment: .bottomTrailing) {
              if isPreviewing {
                PreviewWaveBadge()
                  .transition(.scale.combined(with: .opacity))
              }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPreviewing)
          VStack(alignment: .leading, spacing: 3) {
            Text(coach.humanName)
              .font(.system(size: 20, weight: .heavy))
              .foregroundStyle(Theme.text)
            Text(coach.roleTag.uppercased())
              .font(.system(size: 11, weight: .heavy))
              .tracking(1.6)
              .foregroundStyle(Theme.accent)
          }
          Spacer()
          if isCurrent {
            Image(systemName: "checkmark.seal.fill")
              .font(.system(size: 22))
              .foregroundStyle(Theme.accent)
          }
        }

        Text(coach.shortDescription)
          .font(.system(size: 14))
          .foregroundStyle(Theme.text)

        Text("“\(coach.sampleLine)”")
          .font(.system(size: 13, weight: .medium))
          .italic()
          .foregroundStyle(Theme.textMuted)
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
              .fill(Theme.surfaceRaised))

        if isCurrent {
          HStack(spacing: 6) {
            Image(systemName: "person.fill.checkmark")
            Text("On \(coach.humanName)'s team")
          }
          .font(.system(size: 14, weight: .heavy))
          .foregroundStyle(Theme.accent)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
        } else {
          AuraButton(title: "Join \(coach.humanName)", systemImage: "person.crop.circle.badge.plus")
          {
            onJoin()
          }
        }
      }
    }
  }
}

// MARK: - Join confirmation beat

private struct JoinConfirmation: View {
  let coach: CoachPersona

  var body: some View {
    VStack(spacing: 14) {
      CoachAvatarView(coach: coach)
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
        .auraGlow(radius: 22, intensity: 0.5)
      Text("You're on \(coach.humanName)'s team")
        .font(.system(size: 20, weight: .heavy))
        .foregroundStyle(Theme.text)
      Text("\(coach.humanName) will be in your corner from here.")
        .font(.system(size: 13))
        .foregroundStyle(Theme.textMuted)
    }
    .padding(28)
    .background(
      RoundedRectangle(cornerRadius: Theme.r22, style: .continuous)
        .fill(Theme.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Theme.r22, style: .continuous)
        .stroke(Theme.accent.opacity(0.4), lineWidth: 1)
    )
    .padding(40)
  }
}

// MARK: - Playing affordance

/// Animated sound-bar badge shown on a coach while their preview lines play.
private struct PreviewWaveBadge: View {
  @State private var animating = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 2) {
      ForEach(0..<3, id: \.self) { i in
        Capsule()
          .fill(Color.white)
          .frame(width: 2.5, height: barHeight(i))
          .animation(
            reduceMotion
              ? nil
              : .easeInOut(duration: 0.4 + Double(i) * 0.08).repeatForever(autoreverses: true),
            value: animating)
      }
    }
    .padding(.horizontal, 7)
    .padding(.vertical, 6)
    .background(Circle().fill(Theme.accent))
    .overlay(Circle().stroke(Theme.bg, lineWidth: 2))
    .onAppear { animating = true }
    .accessibilityLabel(Text("Playing preview"))
  }

  private func barHeight(_ i: Int) -> CGFloat {
    guard !reduceMotion else { return [10, 14, 10][i] }
    let bases: [CGFloat] = [8, 14, 10]
    let peaks: [CGFloat] = [16, 8, 18]
    return animating ? peaks[i] : bases[i]
  }
}

#Preview {
  CoachGalleryView().environment(AppState.preview)
}
