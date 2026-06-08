import SwiftUI

/// Onboarding personalization quiz — 13 steps per the playbook spec.
struct OnboardingFlowView: View {
    @Environment(AppState.self) private var app
    @State private var step: Int = 0
    @State private var draft = QuizResult()
    @State private var anx: [Double] = [3, 3, 3]
    @State private var avd: [Double] = [3, 3, 3]

    private let totalSteps = 13

    var body: some View {
        ZStack {
            AuraBackground()
            VStack(spacing: 18) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Group {
                            switch step {
                            case 0:  welcomeStep
                            case 1:  ageStep
                            case 2:  goalStep
                            case 3:  experienceStep
                            case 4:  focusStep
                            case 5:  attachmentStep
                            case 6:  flirtingStep
                            case 7:  confidenceStep
                            case 8:  coachStep
                            case 9:  dailyGoalStep
                            case 10: accountStep
                            case 11: cameraPrimerStep
                            default: resultsStep
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 6)
                }
                .scrollIndicators(.hidden)

                bottomCTA
            }
        }
        .trackView("OnboardingFlowView")
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                if step > 0 { withAnimation(.smooth) { step -= 1 } }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface).overlay(Circle().stroke(Theme.border, lineWidth: 1)))
            }
            .opacity(step == 0 ? 0 : 1)

            VStack(alignment: .leading, spacing: 6) {
                Text("Step \(step + 1) of \(totalSteps)")
                    .font(.system(size: 11, weight: .bold)).tracking(1.1)
                    .foregroundStyle(Theme.textMuted)
                AuraProgressBar(progress: Double(step + 1) / Double(totalSteps))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    // MARK: Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 10) {
            AuraButton(title: ctaTitle) { advance() }
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1 : 0.4)
            if step > 1 && step < totalSteps - 1 {
                Button {
                    withAnimation(.smooth) { step += 1 }
                } label: {
                    Text("Skip for now").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
    }

    private var ctaTitle: String {
        switch step {
        case 0: return "Get started"
        case 11: return "Got it"
        case totalSteps - 1: return "Start my first lesson — free"
        default: return "Continue"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 1: return draft.username.count >= 0  // age step → just confirm
        case 2: return draft.goal != nil
        case 3: return draft.experience != nil
        case 4: return !draft.focusAreas.isEmpty
        case 6: return draft.flirting != nil
        case 8: return draft.coach != nil
        case 10: return draft.username.trimmingCharacters(in: .whitespaces).count >= 2
        default: return true
        }
    }

    private func advance() {
        if step == 5 {
            draft.attachmentAnxiety = anx.reduce(0, +) / 3
            draft.attachmentAvoidance = avd.reduce(0, +) / 3
        }
        if step >= totalSteps - 1 {
            app.applyQuiz(draft)
            return
        }
        withAnimation(.smooth) { step += 1 }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 24)
            BrandLogo(size: .hero(140))
            VStack(spacing: 10) {
                Text("Charmster")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Theme.textMuted)
                Text("Practice love.\nBuild real confidence.")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textPrimary)
                Text("Charmster is a flight simulator for dating. Watch a short lecture, practice with an AI, get scored, level up.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
            }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var ageStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Quick age check", subtitle: "Charmster is for 17+ only. We never share this.")
            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 22)).foregroundStyle(Theme.calmBlue)
                    Text("I confirm I'm 17 or older.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("What brings you to Charmster?", subtitle: "Pick the one that fits best — we'll tailor your start.")
            VStack(spacing: 10) {
                ForEach(OnbGoal.allCases) { g in
                    SelectableCard(text: g.rawValue, selected: draft.goal == g) {
                        draft.goal = g
                    }
                }
            }
        }
    }

    private var experienceStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("How much dating have you done?", subtitle: "Sets your default difficulty.")
            VStack(spacing: 10) {
                ForEach(OnbExperience.allCases) { e in
                    SelectableCard(text: e.rawValue, selected: draft.experience == e) {
                        draft.experience = e
                    }
                }
            }
        }
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("What do you want to work on?", subtitle: "Pick a few. We'll surface lessons that fit.")
            let cols = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(OnbFocusArea.allCases) { f in
                    let on = draft.focusAreas.contains(f)
                    Button {
                        if on { draft.focusAreas.remove(f) } else { draft.focusAreas.insert(f) }
                    } label: {
                        Text(f.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(on ? .white : Theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(on ? AnyShapeStyle(Theme.aura) : AnyShapeStyle(Theme.surface))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(on ? Color.clear : Theme.border, lineWidth: 1)
                                    )
                            )
                            .shadow(color: on ? Theme.auraGlow : .clear, radius: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var attachmentStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("A quick check-in", subtitle: "Six prompts. There are no wrong answers — this just personalizes your coach.")
            ForEach(0..<3, id: \.self) { i in
                AgreeScale(prompt: anxiousPrompts[i], value: $anx[i])
            }
            ForEach(0..<3, id: \.self) { i in
                AgreeScale(prompt: avoidantPrompts[i], value: $avd[i])
            }
        }
    }

    private let anxiousPrompts = [
        "I worry the people I like don't really feel the same way.",
        "I think about texts a lot before sending them.",
        "I want to feel really sure she likes me back."
    ]
    private let avoidantPrompts = [
        "I prefer keeping things light and not too serious.",
        "I get uncomfortable when someone leans in fast.",
        "I'd rather handle hard feelings on my own."
    ]

    private var flirtingStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("What's your flirting style?", subtitle: "We'll lean your AI partner and tips toward this.")
            VStack(spacing: 10) {
                ForEach(OnbFlirtingStyle.allCases) { s in
                    SelectableCard(text: s.rawValue, selected: draft.flirting == s) {
                        draft.flirting = s
                    }
                }
            }
        }
    }

    private var confidenceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("How confident do you feel dating right now?", subtitle: "Slide to where you honestly are. It's just a starting point.")
            GlassCard {
                VStack(spacing: 14) {
                    Text("\(Int(draft.confidence))")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.aura)
                    Slider(value: $draft.confidence, in: 0...100, step: 1)
                        .tint(Theme.pink)
                    HStack {
                        Text("Low").foregroundStyle(Theme.calmBlue)
                        Spacer()
                        Text("Moderate").foregroundStyle(Theme.textMuted)
                        Spacer()
                        Text("High").foregroundStyle(Theme.gold)
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
            }
        }
    }

    private var coachStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Pick your coach", subtitle: "Five styles. You can switch any time.")
            VStack(spacing: 10) {
                ForEach(CoachMode.allCases) { c in
                    let on = draft.coach == c
                    Button { draft.coach = c } label: {
                        HStack(spacing: 14) {
                            Text(c.emoji).font(.system(size: 28))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.displayName)
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(c.tagline)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(on ? AnyShapeStyle(Theme.aura) : AnyShapeStyle(Theme.textMuted))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(on ? AnyShapeStyle(Theme.aura) : AnyShapeStyle(Theme.border),
                                                lineWidth: on ? 1.5 : 1)
                                )
                                .shadow(color: on ? Theme.auraGlow : .clear, radius: 18)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dailyGoalStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Daily practice goal", subtitle: "Tiny daily reps beat marathons.")
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        ForEach([5, 10, 15, 20], id: \.self) { m in
                            let on = draft.dailyMinutes == m
                            Button { draft.dailyMinutes = m } label: {
                                Text("\(m) min")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(
                                        Capsule().fill(on ? AnyShapeStyle(Theme.aura) : AnyShapeStyle(Theme.elevated))
                                    )
                                    .foregroundStyle(on ? .white : Theme.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Toggle(isOn: $draft.reminderEnabled) {
                        Text("Daily reminder")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .tint(Theme.pink)
                }
            }
        }
    }

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("What should we call you?", subtitle: "Choose any name. You can change it later.")
            GlassCard {
                TextField("", text: $draft.username, prompt:
                            Text("Your name").foregroundStyle(Theme.textMuted))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.words)
                    .padding(.vertical, 6)
            }
        }
    }

    private var cameraPrimerStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Camera & mic, one note", subtitle: "Heads up before your first live session.")
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    primerRow("video.fill", "Live practice uses your camera & mic", Theme.pink)
                    primerRow("eye.slash.fill", "Streams are processed live — never recorded or stored", Theme.calmBlue)
                    primerRow("hand.raised.fill", "You can switch to audio-only or text any time", Theme.gold)
                }
            }
        }
    }

    private var resultsStep: some View {
        let track = Curriculum.tracks.first { $0.id == draft.recommendedTrack } ?? Curriculum.tracks[1]
        return VStack(alignment: .leading, spacing: 16) {
            stepTitle("Your starting point", subtitle: nil)
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        TagPill(text: draft.attachmentLabel.rawValue, tint: Theme.purple)
                        TagPill(text: draft.flirting?.rawValue ?? "Playful & teasing", tint: Theme.pink)
                        Spacer()
                    }
                    Text(draft.attachmentLabel.strengthLine)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            GlassCard {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Theme.aura).frame(width: 56, height: 56)
                        Image(systemName: track.symbol).foregroundStyle(.white)
                            .font(.system(size: 22, weight: .bold))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Track \(track.number) — \(track.name)")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text("This fits where you are. We'll adjust as you go.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            HStack(spacing: 10) {
                TagPill(text: "Default tier: \(draft.defaultTier.label)", tint: Theme.calmBlue)
                TagPill(text: "Coach: \(draft.coach?.displayName ?? "Wingman")", tint: Theme.gold)
            }
            Text("Results are a growth starting point — not a verdict.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
    }

    // MARK: helpers

    @ViewBuilder
    private func stepTitle(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func primerRow(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 28)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }
}

private struct SelectableCard: View {
    let text: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.aura)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(selected ? AnyShapeStyle(Theme.aura) : AnyShapeStyle(Theme.border),
                                    lineWidth: selected ? 1.5 : 1)
                    )
                    .shadow(color: selected ? Theme.auraGlow : .clear, radius: 16)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AgreeScale: View {
    let prompt: String
    @Binding var value: Double  // 1...5
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(prompt)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { i in
                        Button { value = Double(i) } label: {
                            Text("\(i)")
                                .font(.system(size: 13, weight: .heavy))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(
                                    Capsule().fill(Int(value) == i
                                                   ? AnyShapeStyle(Theme.aura)
                                                   : AnyShapeStyle(Theme.elevated))
                                )
                                .foregroundStyle(Int(value) == i ? .white : Theme.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    Text("Disagree").foregroundStyle(Theme.textMuted)
                    Spacer()
                    Text("Agree").foregroundStyle(Theme.textMuted)
                }
                .font(.system(size: 11, weight: .semibold))
            }
        }
    }
}

#Preview {
    OnboardingFlowView().environment(AppState()).preferredColorScheme(.dark)
}
