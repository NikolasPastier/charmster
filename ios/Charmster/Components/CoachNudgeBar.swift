import SwiftUI

/// UX4 — the live-practice "Coach Nudge" bar.
///
/// A compact glass bar that sits ABOVE the practice controls and gives one
/// short cue in the coach's voice after a user turn. It never blocks typing or
/// steals scroll focus: it's a passive overlay with a left coach badge, one
/// sentence, optional "Try this" / "Why" chips, and a dismiss affordance
/// (tap X or swipe down). Reduced-motion uses a plain fade.
struct CoachNudgeBar: View {
  let nudge: Nudge
  let coach: CoachPersona
  @Bindable var coordinator: CoachNudgeCoordinator

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dragOffset: CGFloat = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 11) {
        coachBadge

        VStack(alignment: .leading, spacing: 3) {
          Text(coach.humanName.uppercased())
            .font(.system(size: 10, weight: .heavy)).tracking(1.1)
            .foregroundStyle(accent)
          Text(nudge.text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.text)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 4)

        Button {
          coordinator.dismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Theme.textMuted)
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss coach nudge")
      }

      if coordinator.showRewrite, let rewrite = nudge.suggestionRewrite {
        expandedRow(icon: "text.bubble.fill", text: rewrite)
      }
      if coordinator.showWhy, let why = nudge.rationale {
        expandedRow(icon: "info.circle.fill", text: why)
      }

      if hasChips {
        HStack(spacing: 8) {
          if nudge.suggestionRewrite != nil {
            chip(
              "Try this", systemImage: "wand.and.stars",
              active: coordinator.showRewrite
            ) {
              coordinator.showRewrite.toggle()
            }
          }
          if nudge.rationale != nil {
            chip("Why", systemImage: "questionmark", active: coordinator.showWhy) {
              coordinator.showWhy.toggle()
            }
          }
          Spacer(minLength: 0)
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(accent.opacity(0.35), lineWidth: 1)
        )
    )
    .padding(.horizontal, 16)
    .offset(y: dragOffset)
    .gesture(
      DragGesture(minimumDistance: 12)
        .onChanged { v in
          // Only allow downward drag to dismiss; ignore upward.
          dragOffset = max(0, v.translation.height)
        }
        .onEnded { v in
          if v.translation.height > 44 {
            coordinator.dismiss()
          } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 }
          }
        }
    )
    .transition(
      reduceMotion
        ? .opacity
        : .move(edge: .bottom).combined(with: .opacity)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(coach.humanName) coach nudge: \(nudge.text)")
  }

  // MARK: - Pieces

  private var coachBadge: some View {
    CoachAvatarView(coach: coach)
      .frame(width: 38, height: 38)
      .clipShape(Circle())
      .overlay(Circle().stroke(accent.opacity(0.5), lineWidth: 1.5))
      .overlay(alignment: .bottomTrailing) {
        Image(systemName: nudge.type.icon)
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(.black)
          .padding(3)
          .background(Circle().fill(accent))
          .offset(x: 3, y: 3)
      }
  }

  private func expandedRow(icon: String, text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(accent)
      Text(text)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Theme.textMuted)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(.leading, 2)
    .transition(.opacity.combined(with: .move(edge: .top)))
  }

  private func chip(
    _ title: String, systemImage: String, active: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 5) {
        Image(systemName: systemImage).font(.system(size: 10, weight: .bold))
        Text(title).font(.system(size: 12, weight: .heavy))
      }
      .foregroundStyle(active ? Color.black : Theme.text)
      .padding(.horizontal, 12).padding(.vertical, 7)
      .background(
        Capsule().fill(active ? AnyShapeStyle(accent) : AnyShapeStyle(Color.white.opacity(0.10)))
      )
    }
    .buttonStyle(.plain)
  }

  private var hasChips: Bool {
    nudge.suggestionRewrite != nil || nudge.rationale != nil
  }

  private var accent: Color {
    switch nudge.type {
    case .praise: return Theme.gold
    case .improvement: return Theme.accent
    case .calibration: return Theme.teal
    }
  }
}

#Preview {
  ZStack {
    Theme.bg.ignoresSafeArea()
    VStack {
      Spacer()
      CoachNudgeBar(
        nudge: Nudge(
          type: .improvement,
          text: "Don't leave her hanging — give her something to grab.",
          suggestionRewrite: "Add a reason or a hook: \"Yeah — and it reminded me of …\"",
          rationale: "One- or two-word replies give her nothing to build on.",
          confidence: 0.8,
          messageTurnIndex: 2,
          coachPersonaId: CoachPersona.default.id),
        coach: .default,
        coordinator: CoachNudgeCoordinator()
      )
      .padding(.bottom, 40)
    }
  }
}
