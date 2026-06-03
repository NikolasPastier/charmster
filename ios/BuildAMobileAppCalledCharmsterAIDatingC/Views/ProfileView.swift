import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var app

    private let weeklyMinutes: [Int] = [12, 18, 6, 22, 0, 14, 9]
    private let dayLabels = ["M","T","W","T","F","S","S"]

    var body: some View {
        Group {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 22) {
                        headerCard
                        statsRow
                        coachCard
                        weeklyChartCard
                        achievementsCard
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                }
                .background(Theme.background)
                .scrollIndicators(.hidden)
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(Theme.background, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
        .trackView("ProfileView")
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.accent.opacity(0.4), Theme.pathBlue.opacity(0.2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 110, height: 110)
                    .blur(radius: 8)
                Circle()
                    .fill(LinearGradient(colors: [Theme.accent, Theme.pathBlue],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                Text(String(app.username.prefix(1)).uppercased())
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
            }
            Text(app.username).font(.titleXL).foregroundStyle(.white)
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(Theme.accent)
                Text("Level \(app.level) · \(app.levelTitle)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatBlock(label: "Total XP", value: "\(app.xp)", tint: Theme.accent)
            StatBlock(label: "Streak", value: "\(app.streak)d", tint: Theme.coral)
            StatBlock(label: "Quests", value: "\(app.completedCount)", tint: Theme.pathBlue)
        }
    }

    private var coachCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("MY COACH")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.6).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.accentDim)
                            .frame(width: 52, height: 52)
                        Image(systemName: app.coachMode.icon)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.coachMode.displayName).font(.titleM).foregroundStyle(.white)
                        Text(app.coachMode.tagline).font(.bodyS).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }

    private var weeklyChartCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("THIS WEEK")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.6).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(weeklyMinutes.reduce(0, +)) min")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
                let maxV = max(weeklyMinutes.max() ?? 1, 1)
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(weeklyMinutes.enumerated()), id: \.offset) { i, v in
                        VStack(spacing: 8) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 22, height: 96)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.6)],
                                                         startPoint: .top, endPoint: .bottom))
                                    .frame(width: 22, height: max(4, CGFloat(v) / CGFloat(maxV) * 96))
                            }
                            Text(dayLabels[i])
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var achievementsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("ACHIEVEMENTS")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.6).foregroundStyle(Theme.textSecondary)

                let badges: [(String, String, Bool)] = [
                    ("First Quest", "checkmark.seal.fill", true),
                    ("7-Day Streak", "flame.fill", false),
                    ("Boss Victor", "trophy.fill", false),
                    ("Smooth Talker", "bubble.left.and.bubble.right.fill", true),
                    ("Voice Op", "waveform", false),
                    ("Pro Charmster", "sparkles", false),
                ]
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                          spacing: 14) {
                    ForEach(Array(badges.enumerated()), id: \.offset) { _, b in
                        BadgeTile(title: b.0, icon: b.1, unlocked: b.2)
                    }
                }
            }
        }
    }
}

private struct StatBlock: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.2).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMed))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rMed)
                .stroke(Theme.border, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(tint).frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.rMed))
                .padding(.horizontal, 12)
        }
    }
}

private struct BadgeTile: View {
    let title: String
    let icon: String
    let unlocked: Bool
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(unlocked ? Theme.accentDim : Color.white.opacity(0.04))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(unlocked ? Theme.accent : Theme.textTertiary)
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(unlocked ? .white : Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ProfileView().environment(AppState()).preferredColorScheme(.dark)
}
