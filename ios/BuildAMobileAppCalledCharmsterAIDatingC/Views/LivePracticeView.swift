import SwiftUI

/// Live AI practice session — full-bleed avatar, real-time feel meter, mic/cam controls.
/// Mocked locally. Production wiring: OpenAI Realtime (voice) + GPT-4o Vision.
struct LivePracticeView: View {
    @Environment(AppState.self) private var app
    let lecture: Lecture
    let onFinish: (SessionResult) -> Void
    let onClose: () -> Void

    @State private var seconds: Int = 0
    @State private var feel: Double = 0.55
    @State private var tip: String? = "Soften the eyes — she just smiled."
    @State private var micOn = true
    @State private var camOn = true
    @State private var endingNow = false
    @State private var partnerSpeaking = false
    @State private var expression: PersonaExpression = .neutral

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let tips = [
        "Great eye contact.",
        "Slow the next reply.",
        "Mirror her energy floor.",
        "One playful callback here.",
        "Pause — let her finish."
    ]

    var body: some View {
        ZStack {
            avatarBackdrop
            VStack {
                topBar
                Spacer()
                if let t = tip {
                    Text(t)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.teal)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(
                            Capsule().fill(.ultraThinMaterial)
                                .overlay(Capsule().stroke(Theme.teal.opacity(0.6), lineWidth: 1))
                        )
                        .shadow(color: Theme.teal.opacity(0.4), radius: 12)
                        .transition(.opacity)
                }
                bottomControls
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            seconds += 1
            withAnimation(.smooth) {
                feel = max(0.2, min(0.95, feel + Double.random(in: -0.06...0.08)))
            }
            // Cycle who's "speaking" every few seconds so the avatar reacts.
            if seconds % 4 == 0 { partnerSpeaking.toggle() }
            if seconds % 6 == 0 { tip = tips.randomElement() }
            withAnimation(.easeInOut(duration: 0.35)) {
                expression = PersonaExpression.forFeel(
                    feel,
                    isSpeaking: partnerSpeaking,
                    isListening: micOn && !partnerSpeaking
                )
            }
        }
        .trackView("LivePracticeView")
    }

    private var avatarBackdrop: some View {
        let persona = app.selectedPersona
        return ZStack {
            LinearGradient(
                colors: persona.palette.fillColors,
                startPoint: .top, endPoint: .bottom
            )
            // Rim glow behind portrait
            Circle()
                .fill(RadialGradient(colors: [persona.palette.rimColor.opacity(0.55), .clear],
                                     center: .center, startRadius: 0, endRadius: 280))
                .frame(width: 560, height: 560)
                .offset(y: -60)
                .blur(radius: 40)

            // Persona portrait — swaps based on expression
            personaPortrait(persona: persona)
                .offset(y: -30)

            // Bottom scrim
            LinearGradient(colors: [.clear, .black.opacity(0.88)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
                .frame(maxHeight: .infinity, alignment: .bottom)
            // Top scrim
            LinearGradient(colors: [.black.opacity(0.65), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func personaPortrait(persona: PartnerPersona) -> some View {
        let name = persona.imageName(for: expression)
        ZStack {
            if UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 360, height: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(persona.palette.rimColor.opacity(0.55), lineWidth: 1.5)
                    )
                    .shadow(color: persona.palette.rimColor.opacity(0.45), radius: 30)
                    .id(name) // forces crossfade on expression change
                    .transition(.opacity)
            } else {
                // Fallback abstract avatar
                Circle()
                    .fill(LinearGradient(colors: [Color.black.opacity(0.5), persona.palette.rimColor.opacity(0.4)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 240, height: 240)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 110, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    )
            }
        }
    }

    private var topBar: some View {
        HStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    HStack(spacing: 6) {
                        Circle().fill(Theme.alertRed).frame(width: 7, height: 7)
                        Text(timerString)
                            .font(.system(size: 13, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                )
                .frame(width: 90, height: 32)
            Spacer()
            Button { endNow() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(.top, 60)
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Connection")
                    .font(.system(size: 11, weight: .heavy)).tracking(1.2)
                    .foregroundStyle(.white.opacity(0.75))
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18)).frame(height: 8)
                    Capsule()
                        .fill(Theme.scoreScale)
                        .frame(width: max(8, feel * 280), height: 8)
                        .shadow(color: Theme.pink.opacity(0.5), radius: 8)
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 18) {
                controlButton(icon: micOn ? "mic.fill" : "mic.slash.fill",
                              tint: micOn ? .white : Theme.calmBlue) { micOn.toggle() }
                Button { endNow() } label: {
                    ZStack {
                        Circle().fill(Theme.alertRed).frame(width: 72, height: 72)
                            .shadow(color: Theme.alertRed.opacity(0.6), radius: 18)
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                controlButton(icon: camOn ? "video.fill" : "video.slash.fill",
                              tint: camOn ? .white : Theme.calmBlue) { camOn.toggle() }
            }
        }
    }

    private func controlButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: 58, height: 58)
                Circle().stroke(.white.opacity(0.25), lineWidth: 1).frame(width: 58, height: 58)
                Image(systemName: icon).foregroundStyle(tint)
                    .font(.system(size: 20, weight: .bold))
            }
        }
        .buttonStyle(.plain)
    }

    private var timerString: String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%01d:%02d", m, s)
    }

    private func endNow() {
        guard !endingNow else { return }
        endingNow = true
        let result = SessionScorer.score(for: lecture, tier: app.difficultyTier)
        onFinish(result)
    }
}

// MARK: - Practice Hub

struct PracticeHubView: View {
    @Environment(AppState.self) private var app
    @State private var current: Lecture?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Practice")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Jump into your next live rep.")
                            .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.top, 20)

                chargeCard

                SectionHeader(title: "Up next")
                if let next = nextLecture {
                    PracticeLectureCard(lecture: next) { current = next }
                }

                SectionHeader(title: "Quick scenarios")
                ForEach(quickScenarios) { lec in
                    PracticeLectureCard(lecture: lec, compact: true) { current = lec }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $current) { lec in
            LectureDetailSheet(lecture: lec)
                .presentationDetents([.large])
                .presentationBackground(Theme.background)
        }
        .trackView("PracticeHubView")
    }

    private var nextLecture: Lecture? {
        Curriculum.lectures(in: app.activeTrack).first { app.state(of: $0) == .current }
    }

    private var quickScenarios: [Lecture] {
        [2, 5, 10, 12].compactMap { Curriculum.lectures(in: $0).first }
    }

    private var chargeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Daily Charge", systemImage: "bolt.fill")
                        .font(.system(size: 13, weight: .heavy)).tracking(1)
                        .foregroundStyle(Theme.gold)
                    Spacer()
                    Text(app.isPro ? "Pro — fair use" : "\(chargeMinutes) of \(chargeCap) min")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary).monospacedDigit()
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.border).frame(height: 8)
                    Capsule().fill(Theme.aura)
                        .frame(width: max(8, CGFloat(chargeMinutes) / CGFloat(chargeCap) * 300),
                               height: 8)
                        .shadow(color: Theme.auraGlow, radius: 10)
                }
                Text("Charge gates live-AI minutes so we never punish mistakes. Quizzes top it up.")
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var chargeCap: Int { 15 }
    private var chargeMinutes: Int { 15 }
}

private struct PracticeLectureCard: View {
    let lecture: Lecture
    var compact: Bool = false
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.aura)
                        .frame(width: compact ? 48 : 60, height: compact ? 48 : 60)
                        .shadow(color: Theme.auraGlow, radius: 14)
                    Image(systemName: "waveform")
                        .font(.system(size: compact ? 18 : 24, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(lecture.title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text(lecture.scenario)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PracticeHubView().environment(AppState()).preferredColorScheme(.dark)
}
