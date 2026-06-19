import SwiftUI

/// Lightweight pre-replay setup sheet. Shown ONLY when a user opens a lecture
/// they've already completed, so they can tweak coach + difficulty for THIS
/// session before playback. First plays never see this — they auto-resolve from
/// the onboarding profile. Overrides apply to the single session unless the user
/// flips "Save as my default", which persists them via `AppState`.
struct LectureReplaySetupView: View {
  @Environment(AppState.self) private var app

  let lecture: Lecture
  /// Returns the chosen coach + difficulty for this session. The sheet owns the
  /// optional "save as default" persistence before calling back.
  let onPlay: (CoachPersona, DifficultyTier) -> Void
  let onCancel: () -> Void

  @State private var coach: CoachPersona
  @State private var tier: DifficultyTier
  @State private var saveAsDefault = false

  init(
    lecture: Lecture,
    initialCoach: CoachPersona,
    initialTier: DifficultyTier,
    onPlay: @escaping (CoachPersona, DifficultyTier) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.lecture = lecture
    self.onPlay = onPlay
    self.onCancel = onCancel
    _coach = State(initialValue: initialCoach)
    _tier = State(initialValue: initialTier)
  }

  var body: some View {
    Group {
      VStack(spacing: 0) {
        grabber
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            header
            coachPicker
            difficultyPicker
            saveToggle
          }
          .padding(.horizontal, 20)
          .padding(.top, 6)
          .padding(.bottom, 18)
        }
        playBar
      }
      .background(AuraBackground())
    }
    .trackView("LectureReplaySetupView")
  }

  private var grabber: some View {
    Capsule()
      .fill(Theme.border)
      .frame(width: 38, height: 5)
      .padding(.top, 10)
      .padding(.bottom, 12)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 7) {
        Image(systemName: "arrow.counterclockwise")
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(Theme.accent)
        Text("REPLAY")
          .font(.system(size: 12, weight: .heavy)).tracking(2)
          .foregroundStyle(Theme.accent)
      }
      Text(lecture.title)
        .font(.system(size: 22, weight: .heavy))
        .foregroundStyle(Theme.text)
      Text("Tweak this run, or keep your usual setup.")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.textMuted)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Coach picker (horizontal avatars)

  private var coachPicker: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Coach", systemImage: "person.line.dotted.person.fill")
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(CoachPersona.library) { c in
            coachChip(c)
          }
        }
        .padding(.vertical, 2)
      }
    }
  }

  private func coachChip(_ c: CoachPersona) -> some View {
    let selected = coach.id == c.id
    return Button {
      coach = c
    } label: {
      VStack(spacing: 8) {
        CoachAvatarView(coach: c, baseState: .idle)
          .frame(width: 70, height: 70)
          .clipShape(Circle())
          .overlay(
            Circle().stroke(selected ? Theme.accent : Theme.border, lineWidth: selected ? 3 : 1)
          )
          .shadow(color: selected ? Theme.accent.opacity(0.4) : .clear, radius: 12)
        Text(c.humanName)
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(selected ? Theme.text : Theme.textMuted)
        Text(c.roleTag)
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(Theme.textMuted)
      }
      .frame(width: 84)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Difficulty selector (segmented)

  private var difficultyPicker: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Difficulty", systemImage: "flame.fill")
      HStack(spacing: 10) {
        ForEach(DifficultyTier.allCases) { t in
          Button {
            tier = t
          } label: {
            VStack(spacing: 4) {
              Text(t.title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Theme.text)
              Text(t.auraEffectLabel)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(t.color)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceRaised))
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(tier == t ? t.color : Theme.border, lineWidth: tier == t ? 2 : 1)
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: - Save toggle

  private var saveToggle: some View {
    Toggle(isOn: $saveAsDefault) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Save as my default")
          .font(.system(size: 14, weight: .heavy))
          .foregroundStyle(Theme.text)
        Text("Use this coach & difficulty going forward.")
          .font(.system(size: 12))
          .foregroundStyle(Theme.textMuted)
      }
    }
    .tint(Theme.accent)
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.7)))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
  }

  // MARK: - Play bar

  private var playBar: some View {
    VStack(spacing: 10) {
      AuraButton(title: "Play", systemImage: "play.fill") {
        if saveAsDefault {
          app.saveSessionDefaults(coach: coach, tier: tier)
        }
        onPlay(coach, tier)
      }
      Button(action: onCancel) {
        Text("Cancel")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(Theme.textMuted)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
    .padding(.bottom, 18)
  }
}

#Preview {
  LectureReplaySetupView(
    lecture: Curriculum.lectures.first!,
    initialCoach: .default,
    initialTier: .silver,
    onPlay: { _, _ in },
    onCancel: {}
  )
  .environment(AppState.preview)
}
