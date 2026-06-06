import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var app
    @State private var settingsOpen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                identity
                statsRow
                SectionHeader(title: "Personalization")
                tagsCard
                SectionHeader(title: "Subscription")
                subscriptionCard
                AuraButton(title: app.isPro ? "Manage subscription" : "Try Pro free for 3 days",
                           icon: "sparkles") {}
                GlassButton(title: "Settings", icon: "gearshape.fill") { settingsOpen = true }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $settingsOpen) {
            SettingsView()
                .presentationBackground(Theme.background)
        }
        .trackView("ProfileView")
    }

    private var identity: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.aura).frame(width: 76, height: 76)
                    .shadow(color: Theme.auraGlow, radius: 18)
                Text(initials).font(.system(size: 26, weight: .heavy)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(app.displayName)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("Level \(app.level) · \(app.levelTitle)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 20)
    }

    private var initials: String {
        let parts = app.displayName.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(label: "Aura", value: "\(Int(app.aura))", tint: AnyShapeStyle(Theme.aura))
            StatTile(label: "XP",   value: "\(app.totalXP)",   tint: AnyShapeStyle(Theme.gold))
            StatTile(label: "Streak", value: "\(app.streakDays)d", tint: AnyShapeStyle(Theme.ember))
            StatTile(label: "Coins", value: "\(app.charmCoins)", tint: AnyShapeStyle(Theme.calmBlue))
        }
    }

    private var tagsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    TagPill(text: app.attachmentLabel.rawValue, tint: Theme.purple)
                    TagPill(text: app.flirting.rawValue, tint: Theme.pink)
                    TagPill(text: "Tier: \(app.difficultyTier.label)", tint: Theme.calmBlue)
                }
                Divider().background(Theme.border)
                HStack(spacing: 14) {
                    Text(app.coachMode.emoji).font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coach: \(app.coachMode.displayName)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text(app.coachMode.tagline)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private var subscriptionCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: app.isPro ? "crown.fill" : "lock.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(app.isPro ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(Theme.calmBlue))
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.isPro ? "Pro" : "Free")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text(app.isPro
                         ? "Unlimited practice (fair use). Daily Double, all 13 tracks."
                         : "1 live session/day · taster lecture per track")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
        }
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    let tint: AnyShapeStyle
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(tint).monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy)).tracking(1)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
    }
}

#Preview {
    ProfileView().environment(AppState()).preferredColorScheme(.dark)
}
