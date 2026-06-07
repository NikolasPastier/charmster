import SwiftUI

/// Lecture detail: short lecture script, primary "Practice this" CTA, then 3-question quiz.
struct LectureDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    let lecture: Lecture

    @State private var route: Route = .lecture
    @State private var session: SessionResult?
    @State private var quizIndex: Int = 0
    @State private var quizCorrect: Int = 0
    @State private var quizDone: Bool = false

    enum Route { case lecture, practice, results, quiz }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch route {
            case .lecture:  lectureScreen
            case .practice: LivePracticeView(lecture: lecture) { result in
                                session = result
                                app.completePractice(lecture: lecture, result: result)
                                route = .results
                            } onClose: { dismiss() }
            case .results:  resultsScreen
            case .quiz:     quizScreen
            }
        }
        .trackView("LectureDetailSheet")
    }

    // MARK: Lecture screen

    private var lectureScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("\(lecture.minutes) min lecture", systemImage: "play.rectangle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textMuted)
                        Text(lectureScript)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(4)
                    }
                }
                GlassCard {
                    HStack(spacing: 14) {
                        Image(systemName: "person.fill.viewfinder")
                            .foregroundStyle(Theme.pink)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's scenario").font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.textMuted)
                            Text(lecture.scenario)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
                HStack(spacing: 10) {
                    TagPill(text: "Tier: \(app.difficultyTier.label)", tint: Theme.calmBlue)
                    TagPill(text: "Coach: \(app.coachMode.displayName)", tint: Theme.gold)
                }
                Spacer(minLength: 12)
                AuraButton(title: "Practice this", icon: "waveform.circle.fill") {
                    if app.canStartLivePractice {
                        app.recordWatched(lecture: lecture)
                        route = .practice
                    } else {
                        // Gated: either no access, or daily cap hit. Send to Superwall.
                        let placement = app.hasAccess
                            ? CharmsterSuperwall.Placement.dailyCapHit
                            : CharmsterSuperwall.Placement.upgradePrompt
                        CharmsterSuperwall.register(
                            placement,
                            source: "lecture_detail_practice_cta",
                            params: ["lecture_id": lecture.id]
                        ) {
                            // If they convert, immediately enter practice.
                            if app.canStartLivePractice {
                                app.recordWatched(lecture: lecture)
                                route = .practice
                            }
                        }
                    }
                }
                if !app.canStartLivePractice {
                    Text("You're out of daily Charge. Upgrade for unlimited practice.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.calmBlue)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                GlassButton(title: "Skip to quiz", icon: "questionmark.circle") {
                    route = .quiz
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var lectureScript: String {
        """
        \(lecture.title). The aim today is small and specific: \
        you'll practice one move, get scored on how it lands, and walk away with one fix.

        Notice that the win isn't her reaction — it's whether you stayed like yourself the whole time. \
        We're building range, not lines. Three minutes of practice tonight beats reading another article.

        When the AI partner starts, take one slow breath before you respond. Keep your face soft, \
        your voice low, and your questions curious — not interview-y. If she goes quiet, let it \
        breathe. Most people fill silence too fast.
        """
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface).overlay(Circle().stroke(Theme.border, lineWidth: 1)))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Track \(lecture.trackId) · Lesson \(lecture.number)")
                    .font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.textMuted)
                Text(lecture.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
    }

    // MARK: Results screen

    @ViewBuilder
    private var resultsScreen: some View {
        if let s = session {
            ResultsView(result: s, lecture: lecture) {
                route = .quiz
            } onClose: {
                dismiss()
            }
        }
    }

    // MARK: Quiz

    private var quizScreen: some View {
        let quiz = Curriculum.quizzes[lecture.id] ?? []
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if quizDone {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quiz complete")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.aura)
                            Text("You got \(quizCorrect) of \(quiz.count) right. +\(quizCorrect * 5) XP")
                                .font(.system(size: 15)).foregroundStyle(Theme.textPrimary)
                            if quizCorrect >= 2 && (app.progress[lecture.id]?.practiced == true) {
                                Label("Lesson mastered — next node unlocked.", systemImage: "lock.open.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.gold)
                            }
                        }
                    }
                    AuraButton(title: "Back to path") { dismiss() }
                } else if quizIndex < quiz.count {
                    let q = quiz[quizIndex]
                    SectionHeader(title: "Question \(quizIndex + 1) of \(quiz.count)")
                    Text(q.prompt)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    VStack(spacing: 10) {
                        ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                            Button {
                                if idx == q.correctIndex { quizCorrect += 1 }
                                if quizIndex + 1 >= quiz.count {
                                    app.recordQuiz(lecture: lecture, score: quizCorrect)
                                    quizDone = true
                                } else {
                                    quizIndex += 1
                                }
                            } label: {
                                HStack {
                                    Text(opt)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Theme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Theme.border, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    LectureDetailSheet(lecture: Curriculum.lectures[3])
        .environment(AppState()).preferredColorScheme(.dark)
}
