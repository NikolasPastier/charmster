import SwiftUI

/// Duolingo-style snaking path. Step 4: capstones render distinctly.
struct RoadmapView: View {
    @Environment(AppState.self) private var app
    @State private var presentedLecture: Lecture?

    var body: some View {
        Group {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        headerCard
                        ForEach(Curriculum.tracks) { track in
                            trackSection(track: track)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                }
                .background(Theme.bg.ignoresSafeArea())
                .navigationTitle("Your path")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").foregroundStyle(Theme.coral)
                            Text("\(app.streakDays)").font(.system(size: 14, weight: .heavy))
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill").foregroundStyle(Theme.accent)
                            Text("\(app.xp)").font(.system(size: 14, weight: .heavy))
                        }
                    }
                }
            }
            .sheet(item: $presentedLecture) { lec in
                LectureDetailSheet(lecture: lec)
                    .environment(app)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .trackView("RoadmapView")
    }

    private var headerCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                BrandLogo(size: .mark(54))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hey \(app.profile.name.isEmpty ? "you" : app.profile.name) —")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                    Text("Pick where to practice today.")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.text)
                }
                Spacer()
            }
        }
    }

    private func trackSection(track: Track) -> some View {
        let lectures = Curriculum.lectures(in: track.id)
        return VStack(alignment: .leading, spacing: 18) {
            SectionHeader(title: track.title, subtitle: track.subtitle, systemImage: track.symbol)
            VStack(spacing: 22) {
                ForEach(Array(lectures.enumerated()), id: \.element.id) { idx, lec in
                    HStack {
                        if idx.isMultiple(of: 2) { Spacer() }
                        LectureNode(
                            lecture: lec,
                            state: app.state(of: lec),
                            onTap: { presentedLecture = lec }
                        )
                        if !idx.isMultiple(of: 2) { Spacer() }
                    }
                }
            }
        }
    }
}

// MARK: - LectureNode

private struct LectureNode: View {
    let lecture: Lecture
    let state: LectureState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    nodeShape
                    iconLayer
                }
                Text(lecture.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 130)
                if lecture.isCapstone {
                    Text("CAPSTONE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .locked || state == .capstoneLocked)
    }

    @ViewBuilder
    private var nodeShape: some View {
        switch state {
        case .locked:
            Circle().fill(Theme.surface)
                .frame(width: 76, height: 76)
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
        case .current:
            Circle().fill(Theme.surfaceRaised)
                .frame(width: 76, height: 76)
                .overlay(Circle().stroke(Theme.accent, lineWidth: 3))
                .shadow(color: Theme.accent.opacity(0.45), radius: 18)
        case .mastered:
            Circle().fill(Theme.accent.opacity(0.18))
                .frame(width: 76, height: 76)
                .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
        case .capstoneLocked:
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.surface)
                .frame(width: 108, height: 108)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Theme.gold.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                )
        case .capstoneAvailable:
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.goldGradient)
                .frame(width: 108, height: 108)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: Theme.gold.opacity(0.6), radius: 24)
        case .capstoneMastered:
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.gold.opacity(0.25))
                .frame(width: 108, height: 108)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Theme.gold, lineWidth: 2)
                )
        }
    }

    private var iconLayer: some View {
        Image(systemName: iconName)
            .font(.system(size: lecture.isCapstone ? 36 : 26, weight: .heavy))
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch state {
        case .locked, .capstoneLocked: return "lock.fill"
        case .current: return "play.fill"
        case .mastered: return "checkmark"
        case .capstoneAvailable: return "crown.fill"
        case .capstoneMastered: return "medal.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .locked, .capstoneLocked: return Theme.textFaint
        case .current, .mastered: return Theme.accent
        case .capstoneAvailable: return .black
        case .capstoneMastered: return Theme.gold
        }
    }
}

#Preview {
    RoadmapView().environment(AppState.preview)
}
