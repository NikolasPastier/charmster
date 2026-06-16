import SwiftUI

/// Energizing final card that transitions straight into the live session. Sets
/// the scene — who she is, where you are, and the one goal — matching the
/// existing practice handoff tone before routing into the configurator.
struct LectureHandoffView: View {
  let lecture: Lecture
  let coach: CoachPersona
  let partner: PartnerPersona
  let setting: PracticeSetting
  let onBegin: () -> Void
  let onClose: () -> Void

  var body: some View {
      Group {
              VStack(spacing: 0) {
          HStack {
            Button {
              onClose()
            } label: {
              Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textMuted)
            }
            .buttonStyle(.plain)
            Spacer()
            TagPill(label: "Live practice", systemImage: "waveform")
          }
          .padding(.horizontal, 18).padding(.top, 10)
          
          Spacer(minLength: 8)
          
          VStack(spacing: 20) {
            CoachAvatarView(coach: coach, baseState: .idle)
              .frame(width: 150, height: 150)
              .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                  .stroke(Theme.border, lineWidth: 1)
              )
              .auraGlow(radius: 24, intensity: 0.45)
          
            VStack(spacing: 8) {
              Text("You're up")
                .font(.system(size: 13, weight: .heavy)).tracking(2)
                .foregroundStyle(Theme.accent)
              Text(lecture.title)
                .font(.system(size: 26, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.text)
            }
          
            GlassCard {
              VStack(alignment: .leading, spacing: 14) {
                sceneRow(
                  icon: "person.fill",
                  label: "Who",
                  value: "\(partner.displayName) — \(partner.blurb)")
                sceneRow(
                  icon: setting.icon,
                  label: "Where",
                  value: "\(setting.title). \(setting.blurb)")
                sceneRow(
                  icon: "target",
                  label: "Goal",
                  value: goalLine)
              }
            }
            .padding(.horizontal, 18)
          }
          
          Spacer(minLength: 8)
          
          VStack(spacing: 10) {
            AuraButton(title: "Set the scene & begin", systemImage: "play.fill") {
              onBegin()
            }
            Text("\(coach.humanName) is in your corner")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(Theme.textFaint)
          }
          .padding(.horizontal, 18)
          .padding(.bottom, 20)
              }
      }
      .trackView("LectureHandoffView")
  }

  private var goalLine: String {
    switch lecture.skill {
    case "Opening": return "Open with one true thing, then one real question."
    case "Presence": return "Hold a calm, chosen pause — warm, not anxious."
    case "Frame": return "Hold your tone if she teases. Don't justify."
    case "Flow": return "Catch one callback from earlier and use it."
    case "Texting": return "Send the message that earns a real reply."
    default: return lecture.scenario
    }
  }

  private func sceneRow(icon: String, label: String, value: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(Theme.accent)
        .frame(width: 30, height: 30)
        .background(Circle().fill(Theme.accent.opacity(0.12)))
      VStack(alignment: .leading, spacing: 3) {
        Text(label.uppercased())
          .font(.system(size: 11, weight: .heavy)).tracking(1.4)
          .foregroundStyle(Theme.textMuted)
        Text(value)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Theme.text)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
  }
}

#Preview {
  ZStack {
    Theme.bg.ignoresSafeArea()
    LectureHandoffView(
      lecture: Curriculum.lectures.first!,
      coach: .default,
      partner: .default,
      setting: .default,
      onBegin: {},
      onClose: {}
    )
    .environment(AppState.preview)
  }
}
