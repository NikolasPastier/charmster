import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppState.self) private var app
    @State private var step: Int = 0
    @State private var quiz = QuizResult()

    var body: some View {
        Group {
            ZStack {
                backgroundGlow
                VStack(spacing: 0) {
                    content
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .trackView("OnboardingFlowView")
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: SplashSlide(onContinue: advance)
        case 1: ValuePropSlide(onContinue: advance)
        case 2: SocialProofSlide(onContinue: advance)
        case 3: QuizChallengeSlide(quiz: $quiz, onContinue: advance)
        case 4: QuizArenaSlide(quiz: $quiz, onContinue: advance)
        case 5: QuizCoachSlide(quiz: $quiz, onContinue: advance)
        case 6: QuizCadenceSlide(quiz: $quiz, onContinue: advance)
        default: CharmScoreRevealSlide(quiz: quiz) {
            app.applyQuizResult(quiz)
        }
        }
    }

    private func advance() {
        withAnimation(.smooth(duration: 0.35)) { step += 1 }
    }

    private var backgroundGlow: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [Theme.accent.opacity(0.18), .clear],
                           center: .topLeading, startRadius: 20, endRadius: 360)
            RadialGradient(colors: [Theme.coral.opacity(0.10), .clear],
                           center: .bottomTrailing, startRadius: 20, endRadius: 400)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Slides

private struct SplashSlide: View {
    let onContinue: () -> Void
    @State private var pulse = false

    var body: some View {
        VStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulse ? 1.08 : 0.95)
                    .blur(radius: 18)
                Circle()
                    .strokeBorder(Theme.accent.opacity(0.6), lineWidth: 2)
                    .frame(width: 160, height: 160)
                Image(systemName: "sparkles")
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(Theme.accent)
                    .shadow(color: Theme.accent.opacity(0.6), radius: 18)
            }
            .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true } }

            Text("Charmster")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 32)
            Text("Practice the real thing.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 6)
            Spacer()
            PrimaryButton(title: "Start My Journey", action: onContinue)
            Text("No cringe. No judgment.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 10)
        }
    }
}

private struct ValuePropSlide: View {
    let onContinue: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer().frame(height: 24)
            Text("Stop faking it.\nStart building it.")
                .font(.displayL)
                .foregroundStyle(.white)
                .lineSpacing(2)

            VStack(spacing: 16) {
                ValueRow(icon: "bubble.left.and.bubble.right.fill", tint: Theme.accent,
                         title: "Practice real conversations",
                         body: "Train with an AI coach that talks back.")
                ValueRow(icon: "waveform.path.ecg", tint: Theme.coral,
                         title: "Brutally honest feedback",
                         body: "No empty pep talks. Real coaching.")
                ValueRow(icon: "gamecontroller.fill", tint: Theme.pathBlue,
                         title: "Level up like a game",
                         body: "Quests, XP, streaks, boss fights.")
            }
            Spacer()
            PrimaryButton(title: "Next", action: onContinue)
        }
    }
}

private struct ValueRow: View {
    let icon: String
    let tint: Color
    let title: String
    let body: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.titleM).foregroundStyle(.white)
                Text(body).font(.bodyS).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }
}

private struct SocialProofSlide: View {
    let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.2)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: ["person.fill","person.fill.checkmark","face.smiling.fill","person.fill","heart.fill"][i])
                                .foregroundStyle(.white.opacity(0.8))
                        )
                        .overlay(Circle().stroke(Theme.background, lineWidth: 3))
                        .offset(x: CGFloat(i - 2) * 36)
                }
            }
            Text("10,000+")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
            Text("Charmsters building real confidence,\none quest at a time.")
                .multilineTextAlignment(.center)
                .font(.titleM)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)

            HStack(spacing: 6) {
                ForEach(0..<5) { _ in
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.accent)
                }
                Text("4.9 · App Store").foregroundStyle(Theme.textSecondary).font(.bodyS).padding(.leading, 6)
            }
            Spacer()
            PrimaryButton(title: "Take the 60-Second Quiz", action: onContinue)
        }
    }
}

// MARK: - Quiz Slides

private struct QuizChallengeSlide: View {
    @Binding var quiz: QuizResult
    let onContinue: () -> Void
    var body: some View {
        QuizScreen(stepIndex: 1, totalSteps: 4,
                   title: "What's your biggest challenge?",
                   subtitle: "We'll start your roadmap here.") {
            VStack(spacing: 12) {
                ForEach(QuizChallenge.allCases) { opt in
                    QuizChoice(text: opt.rawValue,
                               selected: quiz.challenge == opt) {
                        quiz.challenge = opt
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", action: onContinue)
                .disabled(quiz.challenge == nil)
                .opacity(quiz.challenge == nil ? 0.4 : 1)
        }
    }
}

private struct QuizArenaSlide: View {
    @Binding var quiz: QuizResult
    let onContinue: () -> Void
    var body: some View {
        QuizScreen(stepIndex: 2, totalSteps: 4,
                   title: "Where do you mostly struggle?",
                   subtitle: "We'll weight your drills to match.") {
            VStack(spacing: 12) {
                ForEach(QuizArena.allCases) { opt in
                    QuizChoice(text: opt.rawValue,
                               selected: quiz.arena == opt) {
                        quiz.arena = opt
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", action: onContinue)
                .disabled(quiz.arena == nil)
                .opacity(quiz.arena == nil ? 0.4 : 1)
        }
    }
}

private struct QuizCoachSlide: View {
    @Binding var quiz: QuizResult
    let onContinue: () -> Void
    var body: some View {
        QuizScreen(stepIndex: 3, totalSteps: 4,
                   title: "Pick your coach.",
                   subtitle: "You can switch any time.") {
            VStack(spacing: 12) {
                ForEach(CoachMode.allCases) { coach in
                    CoachOptionCard(coach: coach, selected: quiz.coach == coach) {
                        quiz.coach = coach
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", action: onContinue)
                .disabled(quiz.coach == nil)
                .opacity(quiz.coach == nil ? 0.4 : 1)
        }
    }
}

private struct QuizCadenceSlide: View {
    @Binding var quiz: QuizResult
    let onContinue: () -> Void
    var body: some View {
        QuizScreen(stepIndex: 4, totalSteps: 4,
                   title: "How much can you practice daily?",
                   subtitle: "Consistency beats intensity.") {
            VStack(spacing: 12) {
                ForEach(QuizCadence.allCases) { opt in
                    QuizChoice(text: opt.rawValue,
                               selected: quiz.cadence == opt) {
                        quiz.cadence = opt
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Reveal My Charm Score", action: onContinue)
                .disabled(quiz.cadence == nil)
                .opacity(quiz.cadence == nil ? 0.4 : 1)
        }
    }
}

private struct QuizScreen<Body: View, Footer: View>: View {
    let stepIndex: Int
    let totalSteps: Int
    let title: String
    let subtitle: String
    @ViewBuilder var content: Body
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i < stepIndex ? Theme.accent : Color.white.opacity(0.12))
                        .frame(height: 4)
                }
            }
            .padding(.top, 24)
            Text(title).font(.titleXL).foregroundStyle(.white)
            Text(subtitle).font(.bodyM).foregroundStyle(Theme.textSecondary)
            content
            Spacer()
            footer
        }
    }
}

private struct QuizChoice: View {
    let text: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                ZStack {
                    Circle().stroke(selected ? Theme.accent : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle().fill(Theme.accent).frame(width: 12, height: 12)
                    }
                }
            }
            .padding(18)
            .background(selected ? Theme.accentDim : Theme.surface,
                        in: RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous)
                    .stroke(selected ? Theme.accent : Theme.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CoachOptionCard: View {
    let coach: CoachMode
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(selected ? 0.25 : 0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: coach.icon).foregroundStyle(Theme.accent).font(.system(size: 20, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(coach.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(coach.tagline)
                        .font(.bodyS).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().stroke(selected ? Theme.accent : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selected { Circle().fill(Theme.accent).frame(width: 12, height: 12) }
                }
            }
            .padding(16)
            .background(selected ? Theme.accentDim : Theme.surface,
                        in: RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous)
                    .stroke(selected ? Theme.accent : Theme.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reveal

private struct CharmScoreRevealSlide: View {
    let quiz: QuizResult
    let onContinue: () -> Void
    @State private var animated: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 12)
            Text("YOUR CHARM SCORE")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Theme.textSecondary)

            ProgressRing(progress: animated, size: 220, lineWidth: 16,
                         tint: Theme.accent, label: "out of 100",
                         value: "\(Int(animated * 100))")
                .onAppear {
                    withAnimation(.easeOut(duration: 1.4)) {
                        animated = Double(quiz.charmScore) / 100.0
                    }
                }

            Text("You've got room to run.")
                .font(.titleL).foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                ResultRow(label: "Your coach", value: quiz.coach?.displayName ?? "Wingman")
                ResultRow(label: "Weak spot", value: quiz.challenge?.rawValue ?? "—")
                ResultRow(label: "Daily target", value: quiz.cadence?.rawValue ?? "—")
            }
            .padding(18)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous).stroke(Theme.border, lineWidth: 1))

            Spacer()
            PrimaryButton(title: "Build My Roadmap", icon: "arrow.right", action: onContinue)
        }
    }
}

private struct ResultRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.bodyS).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
        }
    }
}

#Preview {
    OnboardingFlowView().environment(AppState()).preferredColorScheme(.dark)
}
