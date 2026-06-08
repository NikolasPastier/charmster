import SwiftUI

/// 3-slide intro + 4-question coach quiz + Charm Score reveal.
struct OnboardingFlowView: View {
    @Environment(AppState.self) private var app
    @State private var step: Int = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            switch step {
            case 0: IntroCarouselView { step = 1 }
            case 1: CoachQuizView { step = 2 }
            default: CharmScoreRevealView { finish() }
            }
        }
    }

    private func finish() {
        app.recomputePersonalization()
        app.hasCompletedOnboarding = true
        CharmsterSuperwall.register(.onboardingComplete)
    }
}

// MARK: - Intro carousel

private struct IntroCarouselView: View {
    let onContinue: () -> Void
    @State private var page: Int = 0

    private let slides: [(String, String, String)] = [
        ("Practice the real thing.",
         "Charmster is your judgment-free social coach. Run live conversations, get real feedback.",
         "sparkles"),
        ("A path, not a hack.",
         "Daily quests, capstones, and spaced reviews — built around how you actually learn.",
         "map.fill"),
        ("Coached by you, for you.",
         "Pick a coach style. Your tone, your difficulty, your pace.",
         "person.line.dotted.person.fill")
    ]

    var body: some View {
        VStack(spacing: 24) {
            BrandLogo(size: .heroLockup(120))
                .padding(.top, 40)

            TabView(selection: $page) {
                ForEach(slides.indices, id: \.self) { i in
                    VStack(spacing: 16) {
                        Image(systemName: slides[i].2)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.bottom, 8)
                        Text(slides[i].0)
                            .font(.system(size: 30, weight: .heavy))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.text)
                        Text(slides[i].1)
                            .font(.system(size: 16))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.textMuted)
                            .padding(.horizontal, 24)
                    }
                    .padding(.horizontal, 24)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxHeight: .infinity)

            AuraButton(title: page == slides.count - 1 ? "Start the quiz" : "Continue",
                       systemImage: "arrow.right") {
                if page < slides.count - 1 { page += 1 } else { onContinue() }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Coach quiz

private struct CoachQuizView: View {
    @Environment(AppState.self) private var app
    let onDone: () -> Void
    @State private var index: Int = 0
    @State private var answers: [Int: Int] = [:]

    private let questions: [(String, [String])] = [
        ("How would you describe your dating experience?",
         ["Brand new", "Some experience", "Plenty, but mixed", "I've been around"]),
        ("Where do you usually freeze?",
         ["The opener", "Mid-conversation flow", "Reading interest", "Closing / next-step"]),
        ("How do you want me to coach you?",
         ["Gentle, supportive", "Direct, blunt", "Scientific, with patterns", "Mission-style"]),
        ("How's your day-to-day confidence?",
         ["Low", "OK", "Pretty good", "High"])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Step \(index + 1) of \(questions.count)")
                    .font(.system(size: 12, weight: .bold)).tracking(1.4)
                    .foregroundStyle(Theme.textMuted).textCase(.uppercase)
                Spacer()
            }
            ProgressView(value: Double(index + 1), total: Double(questions.count))
                .tint(Theme.accent)

            Text(questions[index].0)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.text)
                .padding(.top, 8)

            VStack(spacing: 10) {
                ForEach(Array(questions[index].1.enumerated()), id: \.offset) { i, opt in
                    Button {
                        answers[index] = i
                        commit()
                        if index < questions.count - 1 {
                            withAnimation(.smooth) { index += 1 }
                        } else {
                            onDone()
                        }
                    } label: {
                        HStack {
                            Text(opt)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Theme.textFaint)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(answers[index] == i ? Theme.accent : Theme.border,
                                        lineWidth: answers[index] == i ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 40)
    }

    private func commit() {
        // Map answers into PersonalizationProfile.
        if let a0 = answers[0] {
            app.profile.experience = ["Brand new", "Some experience", "Plenty, but mixed", "Veteran"][a0]
        }
        if let a1 = answers[1] {
            let focus = ["Opening", "Flow", "Calibration", "Closing"][a1]
            app.profile.focusAreas.insert(focus)
        }
        if let a2 = answers[2] {
            app.coachMode = [.therapist, .bigBrother, .scientist, .wingman][a2]
        }
        if let a3 = answers[3] {
            app.profile.confidence = [3, 5, 7, 9][a3]
            app.profile.attachmentAnxiety = [0.7, 0.5, 0.35, 0.25][a3]
        }
    }
}

// MARK: - Charm Score reveal

private struct CharmScoreRevealView: View {
    @Environment(AppState.self) private var app
    let onContinue: () -> Void
    @State private var displayedScore: Int = 0

    private var targetScore: Int {
        // Quick mock: based on confidence + experience
        20 + app.profile.confidence * 4
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("Your Charm Score")
                .font(.system(size: 13, weight: .bold)).tracking(1.6)
                .foregroundStyle(Theme.textMuted).textCase(.uppercase)
            ScoreRing(value: displayedScore, size: 200, lineWidth: 16, label: "out of 100")
            Text("That's where we start — and it climbs fast.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Your coach", systemImage: app.coachMode.icon)
                    Text(app.coachMode.title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.text)
                    Text(app.coachMode.blurb)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .padding(.horizontal, 22)

            Spacer()
            AuraButton(title: "Start training", systemImage: "sparkles", action: onContinue)
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
        }
        .task {
            for v in 0...targetScore {
                try? await Task.sleep(nanoseconds: 18_000_000)
                displayedScore = v
            }
        }
    }
}

#Preview {
    OnboardingFlowView().environment(AppState())
}
