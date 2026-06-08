import SwiftUI

/// Neutral conversation screen. Camera + mic stay ON (powers the review), but
/// the UI does NOT look like a phone call. No big red hang-up, no recording dot.
struct LivePracticeView: View {
    @Environment(AppState.self) private var app
    let lecture: Lecture?
    let config: SessionConfig
    let onFinish: (SessionResult) -> Void
    let onClose: () -> Void

    @State private var pipeline = LiveSessionPipeline()
    @State private var elapsed: Int = 0
    @State private var expression: PersonaExpression = .neutral
    @State private var showSelfView: Bool = true
    @State private var showCaptions: Bool = true
    @State private var winddown: Bool = false
    @State private var ended: Bool = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var practiceLimitSeconds: Int {
        let base: Int
        if let lec = lecture {
            base = lec.isCapstone ? max(480, lec.minutes * 60) : lec.minutes * 60
        } else {
            base = 7 * 60  // sandbox: ~7 min
        }
        return min(max(base, 150), lecture?.isCapstone == true ? 600 : 600)
    }

    private var remaining: Int { max(0, practiceLimitSeconds - elapsed) }

    var body: some View {
        ZStack {
            backdrop
            VStack {
                topBar
                Spacer()
                avatarBlock
                Spacer()
                if showCaptions, !pipeline.captionsBuffer.isEmpty {
                    Text(pipeline.captionsBuffer)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .padding(.horizontal, 22)
                }
                bottomBar
            }
            if winddown { winddownOverlay }
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.bg)
        .task { await pipeline.start(prefersCamera: config.mode == .videoVoice) }
        .onReceive(timer) { _ in tickFrame() }
        .onDisappear { pipeline.stop() }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        LinearGradient(colors: config.persona.palette.fillColors,
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: - Top bar (minimal)

    private var topBar: some View {
        HStack {
            Button(action: endNow) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.text)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(timeString(remaining))
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(remaining < 30 ? Theme.coral : Theme.text)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(.ultraThinMaterial))
            Spacer()
            Button {
                showSelfView.toggle()
            } label: {
                Image(systemName: showSelfView ? "rectangle.inset.filled.and.person.filled" : "person.crop.rectangle")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.text)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    // MARK: - Avatar

    private var avatarBlock: some View {
        ZStack {
            Circle()
                .fill(Theme.aura.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 28)
            AsyncImage(url: AvatarImageURL.url(for: config.persona, expression: expression)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .empty: ProgressView().tint(Theme.textMuted)
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable().foregroundStyle(Theme.textFaint)
                }
            }
            .frame(width: 220, height: 220)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 2))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
        }
        .overlay(alignment: .topTrailing) {
            if showSelfView {
                SelfViewPlaceholder(active: pipeline.cameraAvailable)
                    .offset(x: 130, y: -90)
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            // Live "feel" meter — thin and subtle
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(pipeline.liveFeel))
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 22)

            HStack(spacing: 10) {
                listeningIndicator
                Spacer()
                Button { showCaptions.toggle() } label: {
                    Image(systemName: showCaptions ? "captions.bubble.fill" : "captions.bubble")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)
                Button(action: endNow) {
                    Text("Done")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22).padding(.bottom, 26)
        }
    }

    private var listeningIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(pipeline.partnerSpeaking ? Theme.coral : Theme.accent)
                .frame(width: 8, height: 8)
            Text(pipeline.partnerSpeaking ? "She's speaking" : "Listening")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
    }

    // MARK: - Winddown overlay

    private var winddownOverlay: some View {
        VStack {
            Spacer()
            Text("Wrapping up — finish your thought.")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Theme.gold))
                .padding(.bottom, 130)
        }
    }

    // MARK: - Tick / end

    private func tickFrame() {
        guard !ended else { return }
        elapsed += 1
        pipeline.tickMockSignals()
        withAnimation(.easeInOut(duration: 0.35)) {
            expression = PersonaExpression.forFeel(
                pipeline.liveFeel,
                isSpeaking: pipeline.partnerSpeaking,
                isListening: !pipeline.partnerSpeaking
            )
        }
        if remaining <= 30 && !winddown {
            withAnimation { winddown = true }
        }
        if remaining == 0 {
            endNow()
        }
    }

    private func endNow() {
        guard !ended else { return }
        ended = true
        pipeline.stop()
        let result = SessionScorer.score(
            lecture: lecture,
            durationSeconds: elapsed,
            tier: config.tier,
            coach: config.coach,
            signals: pipeline.signals,
            isSandbox: config.isSandbox,
            sandboxScored: config.sandboxScored
        )
        onFinish(result)
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Self view

private struct SelfViewPlaceholder: View {
    let active: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.55))
            if active {
                Image(systemName: "person.crop.rectangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.text.opacity(0.7))
            } else {
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .frame(width: 78, height: 104)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    LivePracticeView(
        lecture: Curriculum.lectures.first,
        config: SessionConfig(persona: .default, setting: .default, tier: .silver,
                              coach: .wingman, mode: .videoVoice,
                              isSandbox: false, sandboxScored: true, sandboxPremise: nil),
        onFinish: { _ in }, onClose: {}
    )
    .environment(AppState.preview)
}
