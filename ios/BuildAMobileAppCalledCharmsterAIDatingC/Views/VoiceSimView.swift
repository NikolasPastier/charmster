import SwiftUI

struct VoiceSimView: View {
    let quest: Quest
    let onClose: (Bool) -> Void
    @Environment(AppState.self) private var app

    @State private var phase: Phase = .session
    @State private var micActive = true
    @State private var elapsed: Int = 0
    @State private var transcript: [TranscriptLine] = TranscriptLine.demo
    @State private var orbPulse: CGFloat = 1

    enum Phase { case session, scorecard }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            ZStack {
                Theme.background.ignoresSafeArea()
                switch phase {
                case .session: sessionView
                case .scorecard: scorecardView
                }
            }
            .onReceive(timer) { _ in
                guard phase == .session else { return }
                elapsed += 1
            }
        }
        .trackView("VoiceSimView")
    }

    private var sessionView: some View {
        VStack(spacing: 18) {
            HStack {
                Button { onClose(false) } label: {
                    Image(systemName: "xmark").foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.surface, in: Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("VOICE SIMULATION")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.6).foregroundStyle(Theme.textSecondary)
                    Text(quest.title)
                        .font(.titleM).foregroundStyle(.white)
                }
                Spacer()
                Text(timeString)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 56)
            }
            .padding(.horizontal, 20).padding(.top, 8)

            Spacer()
            orbView
            VStack(spacing: 4) {
                Text("Zoe").font(.titleL).foregroundStyle(.white)
                Text("Curious · Playful · 28")
                    .font(.bodyS).foregroundStyle(Theme.textSecondary)
            }
            Spacer()

            // Transcript
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(transcript) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text(line.speaker.uppercased())
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(1.4)
                                .foregroundStyle(line.isUser ? Theme.accent : Theme.coral)
                                .frame(width: 44, alignment: .leading)
                            Text(line.text)
                                .font(.bodyM).foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                .padding(16)
            }
            .frame(height: 150)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 20)

            HStack(spacing: 36) {
                Spacer()
                Button {
                    withAnimation { micActive.toggle() }
                } label: {
                    ZStack {
                        Circle().fill(micActive ? Theme.accent : Color.white.opacity(0.12))
                            .frame(width: 84, height: 84)
                            .shadow(color: micActive ? Theme.accent.opacity(0.5) : .clear, radius: 18)
                        Image(systemName: micActive ? "mic.fill" : "mic.slash.fill")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(micActive ? .black : .white)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    withAnimation(.smooth) { phase = .scorecard }
                } label: {
                    ZStack {
                        Circle().fill(Theme.coral).frame(width: 60, height: 60)
                        Image(systemName: "phone.down.fill").foregroundStyle(.white)
                            .font(.system(size: 22, weight: .bold))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    private var orbView: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.accent.opacity(0.18 - Double(i) * 0.05))
                    .frame(width: 200 + CGFloat(i) * 40,
                           height: 200 + CGFloat(i) * 40)
                    .blur(radius: 30)
                    .scaleEffect(orbPulse)
            }
            Circle()
                .fill(LinearGradient(colors: [Theme.accent, Theme.pathBlue],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 140, height: 140)
                .blur(radius: 4)
                .scaleEffect(orbPulse)
            Circle()
                .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: 156, height: 156)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                orbPulse = 1.08
            }
        }
    }

    private var timeString: String {
        let m = elapsed / 60, s = elapsed % 60
        return String(format: "%01d:%02d", m, s)
    }

    // MARK: - Scorecard

    private var scorecardView: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    Button { onClose(false) } label: {
                        Image(systemName: "xmark").foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.surface, in: Circle())
                    }
                }

                Text("Session Complete").font(.displayL).foregroundStyle(.white)

                ProgressRing(progress: 0.71, size: 180, lineWidth: 14,
                             tint: Theme.accent, label: "charm score", value: "71")

                HStack(spacing: 16) {
                    SmallRing(label: "Charisma", value: 78, tint: Theme.accent)
                    SmallRing(label: "Listening", value: 64, tint: Theme.pathBlue)
                    SmallRing(label: "Flow", value: 72, tint: Theme.coral)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: app.coachMode.icon).foregroundStyle(Theme.accent)
                            Text(app.coachMode.displayName.uppercased())
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(1.6).foregroundStyle(Theme.textSecondary)
                        }
                        Text(coachFeedback)
                            .font(.bodyM).foregroundStyle(.white)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill").foregroundStyle(Theme.accent)
                    Text("+75 XP Earned")
                        .font(.titleM).foregroundStyle(.white)
                    Spacer()
                }
                .padding(14)
                .background(Theme.accentDim, in: RoundedRectangle(cornerRadius: Theme.rMed))
                .overlay(RoundedRectangle(cornerRadius: Theme.rMed).stroke(Theme.accent.opacity(0.4), lineWidth: 1))

                HStack(spacing: 12) {
                    PrimaryButton(title: "Try Again", variant: .outline) {
                        elapsed = 0
                        withAnimation { phase = .session }
                    }
                    PrimaryButton(title: "Continue") { onClose(true) }
                }
            }
            .padding(20)
        }
    }

    private var coachFeedback: String {
        switch app.coachMode {
        case .hypeMan:
            return "You opened with warmth — that landed. Watch the rapid-fire questions in the middle; let her finish one thread before starting another. One more rep and your flow score breaks 80."
        case .wingman:
            return "Strong open. You lost her in the middle when you bailed on your own story. Hold the thread for one more beat next time — let her ask the follow-up. You're closer than you think."
        case .hardTruth:
            return "You bailed twice. Once on the joke, once on the silence. The silence wasn't bad — you panicked. Hold it for two seconds. That's where chemistry actually lives."
        }
    }
}

private struct SmallRing: View {
    let label: String
    let value: Int
    let tint: Color
    var body: some View {
        VStack(spacing: 6) {
            ProgressRing(progress: Double(value)/100, size: 78, lineWidth: 7,
                         tint: tint, value: "\(value)")
            Text(label).font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

struct TranscriptLine: Identifiable {
    let id = UUID()
    let speaker: String
    let isUser: Bool
    let text: String

    static let demo: [TranscriptLine] = [
        .init(speaker: "zoe", isUser: false, text: "Okay I have to ask — what made you actually say hi instead of just looking up?"),
        .init(speaker: "you", isUser: true, text: "Your book. I've been meaning to read it but kept chickening out."),
        .init(speaker: "zoe", isUser: false, text: "Brave admission. So what's stopping you?"),
    ]
}

#Preview {
    VoiceSimView(quest: Quest.sampleRoadmap[3]) { _ in }
        .environment(AppState())
        .preferredColorScheme(.dark)
}
