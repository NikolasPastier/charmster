import SwiftUI

// MARK: - Onboarding design kit
//
// Shared building blocks for the first-run onboarding flow. These are kept
// onboarding-specific (not in the general UIKit component file) so the flow can
// evolve its visual language without affecting the rest of the app.

// MARK: - Gradient progress bar

/// Thin gradient progress bar shown across every onboarding step.
/// 90° #4C8DFF → #8A5CFF → #FF4D94 → #FFC23D, per the spec.
struct OnboardingProgressBar: View {
  /// Current step (1-based) and total step count.
  let step: Int
  let total: Int

  private var fraction: Double {
    guard total > 0 else { return 0 }
    return min(1, max(0, Double(step) / Double(total)))
  }

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(Theme.surfaceRaised)
        Capsule()
          .fill(
            LinearGradient(
              colors: [
                Color(hex: 0x4C8DFF), Color(hex: 0x8A5CFF),
                Color(hex: 0xFF4D94), Color(hex: 0xFFC23D),
              ],
              startPoint: .leading, endPoint: .trailing
            )
          )
          .frame(width: max(8, geo.size.width * fraction))
          .animation(.spring(response: 0.45, dampingFraction: 0.85), value: fraction)
      }
    }
    .frame(height: 6)
  }
}

// MARK: - Step scaffold

/// Standard onboarding step container: progress bar + back button at the top,
/// a title/subtitle header, scrollable content, and a pinned bottom CTA.
struct OnboardingStep<Content: View, Footer: View>: View {
  let step: Int
  let total: Int
  var title: String
  var subtitle: String? = nil
  var onBack: (() -> Void)? = nil
  @ViewBuilder var content: () -> Content
  @ViewBuilder var footer: () -> Footer

  @State private var titleShown = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        if let onBack {
          Button(action: onBack) {
            Image(systemName: "chevron.left")
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(Theme.textMuted)
              .frame(width: 34, height: 34)
              .background(Circle().fill(Theme.surface))
              .overlay(Circle().stroke(Theme.border, lineWidth: 1))
          }
          .buttonStyle(.plain)
        }
        OnboardingProgressBar(step: step, total: total)
      }
      .padding(.horizontal, 22)
      .padding(.top, 8)

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 8) {
            Text(title)
              .font(.system(size: 28, weight: .heavy))
              .foregroundStyle(Theme.text)
              .fixedSize(horizontal: false, vertical: true)
              .scaleEffect(titleShown ? 1.0 : 0.92, anchor: .leading)
              .opacity(titleShown ? 1.0 : 0.0)
              .onAppear {
                withAnimation(
                  reduceMotion
                    ? .easeOut(duration: 0.18)
                    : .spring(response: 0.42, dampingFraction: 0.6)
                ) { titleShown = true }
              }
            if let subtitle {
              Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Theme.text.opacity(0.80))
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(.top, 18)

          content()
          Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
      }

      VStack(spacing: 10) { footer() }
        .padding(.horizontal, 22)
        .padding(.bottom, 26)
        .padding(.top, 6)
    }
  }
}

// MARK: - Option card

/// Selectable option row with a leading icon. Selected = Aura gradient
/// border/fill + checkmark, with a subtle spring + light haptic on tap.
struct OnboardingOptionCard: View {
  let title: String
  var subtitle: String? = nil
  var systemImage: String? = nil
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button {
      #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      #endif
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
    } label: {
      HStack(spacing: 12) {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(isSelected ? Theme.text : Theme.accent)
            .frame(width: 38, height: 38)
            .background(
              Circle().fill(isSelected ? Color.white.opacity(0.12) : Theme.accent.opacity(0.12)))
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(Theme.text)
          if let subtitle {
            Text(subtitle)
              .font(.system(size: 13))
              .foregroundStyle(Theme.textMuted)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 8)
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 20))
          .foregroundStyle(isSelected ? Theme.accent : Theme.textMuted)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(isSelected ? Theme.surfaceRaised : Theme.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(
            isSelected
              ? AnyShapeStyle(Theme.accentGradient)
              : AnyShapeStyle(Theme.border),
            lineWidth: isSelected ? 2 : 1
          )
      )
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Likert scale row (attachment check-in)

/// A single 1–5 agreement row used by the attachment check-in. Renders five
/// tappable dots; the filled run uses the score gradient.
struct LikertRow: View {
  let prompt: String
  /// 1...5, or nil if unanswered.
  let value: Int?
  let onChange: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(prompt)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Theme.text)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 10) {
        ForEach(1...5, id: \.self) { n in
          let on = (value ?? 0) >= n
          Button {
            #if canImport(UIKit)
              UISelectionFeedbackGenerator().selectionChanged()
            #endif
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { onChange(n) }
          } label: {
            Circle()
              .fill(
                on
                  ? AnyShapeStyle(Theme.scoreScale)
                  : AnyShapeStyle(Theme.surfaceRaised)
              )
              .frame(width: 26, height: 26)
              .overlay(Circle().stroke(on ? Color.clear : Theme.border, lineWidth: 1))
              .scaleEffect(value == n ? 1.12 : 1)
          }
          .buttonStyle(.plain)
        }
        Spacer()
      }
      HStack {
        Text("Disagree").font(.system(size: 11)).foregroundStyle(Theme.textMuted)
        Spacer()
        Text("Agree").font(.system(size: 11)).foregroundStyle(Theme.textMuted)
      }
    }
  }
}

// MARK: - Benefit row (hero)

struct OnboardingBenefitRow: View {
  let systemImage: String
  let title: String
  let subtitle: String

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: systemImage)
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(Theme.text)
        .frame(width: 46, height: 46)
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Theme.accentGradient.opacity(0.9))
        )
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.text)
        Text(subtitle)
          .font(.system(size: 13)).foregroundStyle(Theme.textMuted)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
  }
}

#Preview {
  ZStack {
    Theme.bg.ignoresSafeArea()
    VStack(spacing: 20) {
      OnboardingProgressBar(step: 4, total: 13).padding(.horizontal)
      OnboardingOptionCard(
        title: "Date with intention", subtitle: "Looking for something real",
        systemImage: "heart.fill", isSelected: true, action: {})
      OnboardingOptionCard(
        title: "Date casually", systemImage: "sparkles", isSelected: false, action: {})
      LikertRow(prompt: "I worry they'll lose interest in me.", value: 3, onChange: { _ in })
      OnboardingBenefitRow(
        systemImage: "waveform", title: "Live AI practice",
        subtitle: "Real conversations, real-time feedback.")
    }
    .padding()
  }
}
