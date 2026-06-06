import SwiftUI

/// Coach Hub: AI tip card + 5 selectable archetypes + recommended lessons.
struct CoachHubView: View {
    @Environment(AppState.self) private var app
    @State private var current: Lecture?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                tipCard
                SectionHeader(title: "Pick your coach")
                coachStrip
                SectionHeader(title: "Recommended for you")
                ForEach(recommended) { lec in
                    RecommendationCard(lecture: lec) { current = lec }
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
        .trackView("CoachHubView")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Coach")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Personalized lessons & coaching tone.")
                .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 20)
    }

    private var tipCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.aura).frame(width: 52, height: 52)
                        .shadow(color: Theme.auraGlow, radius: 12)
                    Text(app.coachMode.emoji).font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's tip")
                        .font(.system(size: 11, weight: .heavy)).tracking(1)
                        .foregroundStyle(Theme.textMuted)
                    Text(tipLine)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var tipLine: String {
        switch app.coachMode {
        case .bigBrother:  return "Let's work on slowing your first reply by one breath today."
        case .scientist:   return "Spark is your lowest meter. Try one playful callback per practice."
        case .alphaMentor: return "Range > polish. Push from Bronze to Silver in your next session."
        case .therapist:   return "Notice when you tighten. We'll practice softening, not performing."
        case .wingman:     return "Quick one — open Track \(app.activeTrack), Lesson 1. Three minutes."
        }
    }

    private var coachStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CoachMode.allCases) { c in
                    let on = app.coachMode == c
                    Button { app.coachMode = c } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(c.emoji).font(.system(size: 28))
                            Text(c.displayName)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Theme.textPrimary)
                            Text(c.tagline)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(14)
                        .frame(width: 160, height: 130, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(on ? AnyShapeStyle(Theme.aura) : AnyShapeStyle(Theme.border),
                                                lineWidth: on ? 2 : 1)
                                )
                                .shadow(color: on ? Theme.auraGlow : .clear, radius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var recommended: [Lecture] {
        // Pull a few lectures spanning Body/Conversation/Texting tracks tied to focus areas.
        let trackIds: [Int] = {
            var ids: Set<Int> = [app.activeTrack]
            for f in app.focusAreas {
                switch f {
                case .openers, .closing: ids.insert(2)
                case .threading: ids.insert(3)
                case .humor: ids.insert(4)
                case .signals: ids.insert(5)
                case .presence: ids.insert(6)
                case .depth: ids.insert(7)
                case .nerves: ids.insert(8)
                }
            }
            return Array(ids).sorted()
        }()
        return trackIds.compactMap { Curriculum.lectures(in: $0).first }
    }
}

private struct RecommendationCard: View {
    let lecture: Lecture
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.elevated)
                        .frame(width: 50, height: 50)
                    Image(systemName: "graduationcap.fill")
                        .foregroundStyle(Theme.aura).font(.system(size: 20, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Track \(lecture.trackId) · \(lecture.title)")
                        .font(.system(size: 15, weight: .heavy))
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

#Preview {
    CoachHubView().environment(AppState()).preferredColorScheme(.dark)
}
