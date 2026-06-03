import SwiftUI
import PhotosUI

struct TextMissionView: View {
    let quest: Quest
    let onClose: (Bool) -> Void
    @Environment(AppState.self) private var app

    @State private var phase: Phase = .upload
    @State private var pickerItem: PhotosPickerItem?
    @State private var uploadedImage: Image?
    @State private var copiedIndex: Int?

    enum Phase { case upload, analyzing, results, complete }

    var body: some View {
        Group {
            NavigationStack {
                ZStack {
                    Theme.background.ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            switch phase {
                            case .upload: uploadView
                            case .analyzing: analyzingView
                            case .results, .complete: resultsView
                            }
                        }
                        .padding(20)
                    }
                    .scrollIndicators(.hidden)
                }
                .navigationTitle("Text Mission")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { onClose(false) } label: {
                            Image(systemName: "xmark").foregroundStyle(.white)
                        }
                    }
                }
                .toolbarBackground(Theme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
        .trackView("TextMissionView")
    }

    // MARK: - Phases

    private var uploadView: some View {
        VStack(alignment: .leading, spacing: 18) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "scope").foregroundStyle(Theme.accent)
                        Text("MISSION BRIEFING")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.6).foregroundStyle(Theme.textSecondary)
                    }
                    Text("Upload a dead conversation.")
                        .font(.titleL).foregroundStyle(.white)
                    Text("Your coach breaks it down move-by-move — what hooked, what dropped, and three replies in your voice.")
                        .font(.bodyM).foregroundStyle(Theme.textSecondary)
                }
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                VStack(spacing: 14) {
                    if let uploadedImage {
                        uploadedImage
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                                .foregroundStyle(Color.white.opacity(0.2))
                            VStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Theme.accentDim).frame(width: 64, height: 64)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundStyle(Theme.accent)
                                }
                                Text("Tap to upload screenshot")
                                    .font(.titleM).foregroundStyle(.white)
                                Text("PNG or JPG · stays on your device")
                                    .font(.bodyS).foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.vertical, 36)
                        }
                        .frame(height: 240)
                    }
                }
            }
            .onChange(of: pickerItem) { _, new in
                guard let new else { return }
                Task {
                    if let data = try? await new.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        uploadedImage = Image(uiImage: ui)
                    } else {
                        uploadedImage = Image(systemName: "doc.richtext")
                    }
                    runAnalysis()
                }
            }

            if uploadedImage == nil {
                Button {
                    // Skip upload with demo conversation for the MVP
                    uploadedImage = Image(systemName: "ellipsis.message.fill")
                    runAnalysis()
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Try with a demo conversation")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(Theme.accentDim, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 40)
            PulsingDot()
            Text("Analyzing your conversation…")
                .font(.titleM).foregroundStyle(.white)
            Text("Your \(app.coachMode.displayName) is reading every beat.")
                .font(.bodyM).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Conversation Autopsy")
                .font(.displayL).foregroundStyle(.white)
            SurfaceCard {
                VStack(spacing: 18) {
                    ScoreBar(label: "Opening Hook", score: 6, tint: Theme.accent)
                    ScoreBar(label: "Engagement Pull", score: 4, tint: Theme.pathBlue)
                    ScoreBar(label: "Emotional Connection", score: 3, tint: Theme.coral)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(Theme.accent).frame(width: 3).cornerRadius(2)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Here's what went wrong")
                        .font(.titleM).foregroundStyle(.white)
                    feedbackBullet("Your opener landed — but you went straight to logistics. You burned the spark.")
                    feedbackBullet("You asked 3 questions in a row. It read like an interview, not a vibe.")
                    feedbackBullet("No callback to the joke at message 4. You left chemistry on the table.")
                    Text("Next move: drop one short, low-stakes statement that gives her something to react to.")
                        .font(.bodyS).foregroundStyle(Theme.accent)
                        .padding(.top, 6)
                }
            }
            .padding(18)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous).stroke(Theme.border, lineWidth: 1))

            Text("Your Next Move")
                .font(.titleL).foregroundStyle(.white)
                .padding(.top, 4)

            VStack(spacing: 12) {
                ForEach(Array(templates.enumerated()), id: \.offset) { idx, t in
                    ReplyTemplateCard(text: t, copied: copiedIndex == idx) {
                        UIPasteboard.general.string = t
                        copiedIndex = idx
                    }
                }
            }

            xpBanner
            PrimaryButton(title: "Complete Mission", icon: "checkmark") {
                onClose(true)
            }
        }
    }

    private var xpBanner: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.accentDim).frame(width: 36, height: 36)
                Image(systemName: "bolt.fill").foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading) {
                Text("+\(quest.xpReward) XP Earned")
                    .font(.titleM).foregroundStyle(.white)
                Text("Banked into your roadmap.")
                    .font(.bodyS).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
    }

    private func feedbackBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.accent).frame(width: 6, height: 6).padding(.top, 7)
            Text(text).font(.bodyM).foregroundStyle(Theme.textPrimary)
        }
    }

    private var templates: [String] {
        switch app.coachMode {
        case .hypeMan:
            return [
                "Okay you actually made me laugh — that's rare. What's the most chaotic thing you've done this week?",
                "I refuse to let you stay this funny without context. Tell me one good story.",
                "Confession: I already know we're getting coffee. The only question is which place."
            ]
        case .wingman:
            return [
                "Real talk — you seem like trouble. Convince me you're not.",
                "I owe you a bad joke for the one you made earlier. Saving it for in-person.",
                "Coffee this week? I know a place that's good enough to justify the walk."
            ]
        case .hardTruth:
            return [
                "You're better in person. Thursday, 7pm, that little place on 4th.",
                "We've been polite for too long. What's actually fun about your week?",
                "Pick a night. I'll pick the place. Don't overthink it."
            ]
        }
    }

    // MARK: - Mock analysis

    private func runAnalysis() {
        phase = .analyzing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.smooth) { phase = .results }
        }
    }
}

private struct ReplyTemplateCard: View {
    let text: String
    let copied: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.bodyM)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(action: onCopy) {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(copied ? Theme.accent : .white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(copied ? Theme.accentDim : Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.rMed, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

struct PulsingDot: View {
    @State private var on = false
    var body: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.25))
                .frame(width: 80, height: 80)
                .scaleEffect(on ? 1.2 : 0.85)
                .opacity(on ? 0 : 1)
            Circle().fill(Theme.accent).frame(width: 24, height: 24)
                .shadow(color: Theme.accent.opacity(0.7), radius: 14)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { on = true }
        }
    }
}

#Preview {
    TextMissionView(quest: Quest.sampleRoadmap[2]) { _ in }
        .environment(AppState())
        .preferredColorScheme(.dark)
}
