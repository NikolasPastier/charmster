import SwiftUI

struct RoadmapView: View {
    @Environment(AppState.self) private var app
    @State private var selectedQuest: Quest?
    @State private var lockedToast: Quest?

    var body: some View {
        Group {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        ForEach(QuestPath.allCases) { path in
                            pathSection(for: path)
                        }
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
                .background(Theme.background)
                .scrollIndicators(.hidden)
                .navigationTitle("")
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .top) { gradientFade }
                .overlay(alignment: .bottom) {
                    if let q = lockedToast { lockToast(for: q) }
                }
                .sheet(item: $selectedQuest) { quest in
                    QuestDetailSheet(quest: quest) { startQuest in
                        selectedQuest = nil
                        handleStart(startQuest)
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.surface)
                }
            }
        }
        .trackView("RoadmapView")
    }

    private var gradientFade: some View {
        LinearGradient(colors: [Theme.background, Theme.background.opacity(0)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 12)
            .allowsHitTesting(false)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                AvatarBadge(initials: String(app.username.prefix(1)).uppercased())
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(Theme.coral)
                    Text("\(app.streak)").font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("day streak").font(.bodyS).foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").foregroundStyle(Theme.accent)
                    Text("\(app.xp)").font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("XP").font(.bodyS).foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Path progress")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(app.completedCount) of \(app.quests.count)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
                LinearProgressBar(progress: app.pathProgress)
            }
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private func handleStart(_ quest: Quest) {
        // For the MVP, only Text Mission Mode is wired. The state will navigate via push.
        // We use a sheet here; deeper navigation handled in the sheet.
        _ = quest
    }

    // MARK: - Path Section

    private func pathSection(for path: QuestPath) -> some View {
        let questsInPath = app.quests.filter { $0.path == path }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Capsule().fill(path.color).frame(width: 4, height: 22)
                Text(path.title.uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(path.color)
                Spacer()
                Text("\(questsInPath.filter { $0.status == .completed }.count)/\(questsInPath.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(path.subtitle)
                .font(.bodyS).foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 4)
            PathNodeColumn(quests: questsInPath, pathColor: path.color) { quest in
                tap(quest)
            }
        }
    }

    private func tap(_ quest: Quest) {
        switch quest.status {
        case .locked:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                lockedToast = quest
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { if lockedToast?.id == quest.id { lockedToast = nil } }
            }
        case .active, .completed:
            selectedQuest = quest
        }
    }

    private func lockToast(for quest: Quest) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill").foregroundStyle(Theme.coral)
            Text("Complete the previous quest to unlock this.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(Theme.surfaceElevated, in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .padding(.bottom, 96)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Node Column (snaking)

struct PathNodeColumn: View {
    let quests: [Quest]
    let pathColor: Color
    let onTap: (Quest) -> Void

    var body: some View {
        VStack(spacing: 18) {
            ForEach(Array(quests.enumerated()), id: \.element.id) { idx, quest in
                HStack {
                    if idx % 2 == 1 { Spacer() }
                    QuestNode(quest: quest, pathColor: pathColor, onTap: { onTap(quest) })
                    if idx % 2 == 0 { Spacer() }
                }
                .overlay(alignment: .center) {
                    // Connector dots to next node
                    if idx < quests.count - 1 {
                        ConnectorDots()
                            .offset(y: 50)
                    }
                }
            }
        }
    }
}

struct ConnectorDots: View {
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { _ in
                Circle().fill(Color.white.opacity(0.18)).frame(width: 4, height: 4)
            }
        }
    }
}

struct QuestNode: View {
    let quest: Quest
    let pathColor: Color
    let onTap: () -> Void
    @State private var pulse = false

    private var size: CGFloat { quest.isBossFight ? 96 : 76 }

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onTap) {
                ZStack {
                    // Pulsing aura for active
                    if quest.status == .active {
                        Circle()
                            .stroke(pathColor.opacity(0.5), lineWidth: 2)
                            .frame(width: size + 24, height: size + 24)
                            .scaleEffect(pulse ? 1.12 : 0.95)
                            .opacity(pulse ? 0 : 1)
                    }
                    Circle()
                        .fill(fillStyle)
                        .frame(width: size, height: size)
                        .overlay(Circle().stroke(strokeColor, lineWidth: quest.status == .active ? 3 : 2))
                        .shadow(color: glow, radius: 14)
                    iconView
                }
            }
            .buttonStyle(.plain)
            .onAppear {
                if quest.status == .active {
                    withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
                }
            }
            if quest.status == .active || quest.isBossFight {
                VStack(spacing: 2) {
                    if quest.isBossFight {
                        Text("BOSS FIGHT")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(Theme.coral)
                    }
                    Text(quest.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 140)
                }
            } else if quest.status == .completed {
                Text(quest.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: 120)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder private var iconView: some View {
        switch quest.status {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.black)
        case .active:
            Image(systemName: quest.isBossFight ? "flame.fill" : "play.fill")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.black)
        case .locked:
            Image(systemName: quest.isBossFight ? "flame.fill" : "lock.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var fillStyle: AnyShapeStyle {
        switch quest.status {
        case .completed: return AnyShapeStyle(LinearGradient(colors: [pathColor, pathColor.opacity(0.6)], startPoint: .top, endPoint: .bottom))
        case .active:
            let c = quest.isBossFight ? Theme.coral : pathColor
            return AnyShapeStyle(LinearGradient(colors: [c, c.opacity(0.65)], startPoint: .top, endPoint: .bottom))
        case .locked:
            return AnyShapeStyle(Theme.surface)
        }
    }

    private var strokeColor: Color {
        switch quest.status {
        case .completed: return pathColor.opacity(0.6)
        case .active: return quest.isBossFight ? Theme.coral : pathColor
        case .locked: return Theme.border
        }
    }

    private var glow: Color {
        switch quest.status {
        case .completed: return pathColor.opacity(0.35)
        case .active: return (quest.isBossFight ? Theme.coral : pathColor).opacity(0.6)
        case .locked: return .clear
        }
    }
}

struct AvatarBadge: View {
    let initials: String
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Theme.accent, Theme.pathBlue],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 42, height: 42)
            Text(initials)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
        }
        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}

#Preview {
    RoadmapView().environment(AppState()).preferredColorScheme(.dark)
}
