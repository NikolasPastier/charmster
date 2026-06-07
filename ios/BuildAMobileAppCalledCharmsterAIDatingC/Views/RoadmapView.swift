import SwiftUI

/// Home / skill path. Sticky top bar + winding vertical path of lecture nodes for the active track.
struct RoadmapView: View {
    @Environment(AppState.self) private var app
    @State private var pickerOpen = false
    @State private var selectedLecture: Lecture?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                topBar
                trackHeader
                pathView
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $pickerOpen) {
            TrackPickerSheet(selection: Binding(
                get: { app.activeTrack },
                set: { app.activeTrack = $0 }
            ))
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.background)
        }
        .sheet(item: $selectedLecture) { lec in
            LectureDetailSheet(lecture: lec)
                .presentationDetents([.large])
                .presentationBackground(Theme.background)
        }
        .trackView("RoadmapView")
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            StatPill(icon: "flame.fill", value: "\(app.streakDays)", tint: Theme.ember)
            StatPill(icon: "bolt.fill", value: "\(app.totalXP)", tint: Theme.gold)
            Spacer()
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Theme.aura).frame(width: 28, height: 28)
                        .shadow(color: Theme.auraGlow, radius: 8)
                    Text("\(app.level)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                }
                Text("Lv \(app.level)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                Capsule().fill(Theme.surface)
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            )
        }
        .padding(.top, 12)
    }

    // MARK: Track header

    private var trackHeader: some View {
        let t = Curriculum.tracks.first { $0.id == app.activeTrack } ?? Curriculum.tracks[1]
        let lectures = Curriculum.lectures(in: t.id)
        let mastered = lectures.filter { app.progress[$0.id]?.mastered == true }.count
        return Button { pickerOpen = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.aura)
                        .frame(width: 54, height: 54)
                        .shadow(color: Theme.auraGlow, radius: 12)
                    Image(systemName: t.symbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Track \(t.number) · \(t.name)")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(mastered) of \(lectures.count) mastered · \(t.blurb)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Path

    private var pathView: some View {
        let lectures = Curriculum.lectures(in: app.activeTrack)
        return VStack(spacing: 0) {
            ForEach(Array(lectures.enumerated()), id: \.element.id) { idx, lec in
                let state = app.state(of: lec)
                LectureNode(
                    lecture: lec,
                    state: state,
                    side: idx % 2 == 0 ? .left : .right,
                    isLast: idx == lectures.count - 1
                ) {
                    if state != .locked { selectedLecture = lec }
                }
            }
        }
    }
}

// MARK: - Lecture node

private enum NodeSide { case left, right }

private struct LectureNode: View {
    @Environment(AppState.self) private var app
    let lecture: Lecture
    let state: LectureState
    let side: NodeSide
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if side == .right { Spacer() }
                button
                if side == .left { Spacer() }
            }
            .padding(.horizontal, 24)
            if !isLast { connector }
        }
    }

    private var button: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(fill)
                        .frame(width: 76, height: 76)
                        .shadow(color: glow, radius: 18)
                    Circle()
                        .stroke(ring, lineWidth: 3)
                        .frame(width: 76, height: 76)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(iconColor)
                    if state == .current {
                        Circle()
                            .stroke(Theme.pink.opacity(0.7), lineWidth: 2)
                            .frame(width: 92, height: 92)
                            .blur(radius: 0.5)
                    }
                }
                Text(lecture.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(state == .locked ? Theme.textMuted : Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 110)
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .locked)
    }

    private var connector: some View {
        VStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { _ in
                Circle().fill(Theme.border).frame(width: 5, height: 5)
            }
        }
        .padding(.vertical, 8)
    }

    private var fill: AnyShapeStyle {
        switch state {
        case .mastered: return AnyShapeStyle(Theme.aura)
        case .current:  return AnyShapeStyle(Theme.elevated)
        case .locked:   return AnyShapeStyle(Theme.surface)
        }
    }
    private var ring: AnyShapeStyle {
        switch state {
        case .mastered: return AnyShapeStyle(Theme.gold)
        case .current:  return AnyShapeStyle(Theme.aura)
        case .locked:   return AnyShapeStyle(Theme.border)
        }
    }
    private var glow: Color {
        switch state {
        case .mastered: return Theme.gold.opacity(0.4)
        case .current:  return Theme.auraGlow
        case .locked:   return .clear
        }
    }
    private var icon: String {
        switch state {
        case .mastered: return "checkmark"
        case .current:  return "play.fill"
        case .locked:   return "lock.fill"
        }
    }
    private var iconColor: Color {
        switch state {
        case .mastered: return .white
        case .current:  return Theme.pink
        case .locked:   return Theme.textMuted
        }
    }
}

// MARK: - Track picker sheet

private struct TrackPickerSheet: View {
    @Binding var selection: Int
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                SectionHeader(title: "Choose a track")
                ForEach(Curriculum.tracks) { t in
                    Button {
                        selection = t.id
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.elevated)
                                    .frame(width: 44, height: 44)
                                Image(systemName: t.symbol).foregroundStyle(Theme.aura)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Track \(t.number) · \(t.name)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(t.blurb)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if selection == t.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.aura)
                            }
                        }
                        .padding(12)
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
            .padding(20)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
    }
}

#Preview {
    RoadmapView().environment(AppState()).preferredColorScheme(.dark)
}
