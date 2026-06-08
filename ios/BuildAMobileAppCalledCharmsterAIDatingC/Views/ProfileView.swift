import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var app
    @State private var goToSettings: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    statsRow
                    upgradeCard
                    pillsRow
                    recentResultsCard
                }
                .padding(18)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationDestination(isPresented: $goToSettings) {
                SettingsView()
            }
        }
    }

    private var headerCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                BrandLogo(size: .mark(54))
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.profile.name.isEmpty ? "Charmster" : app.profile.name)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Theme.text)
                    Text("Level \(max(1, app.xp / 500 + 1)) · \(app.profile.attachmentLabel)")
                        .font(.system(size: 13)).foregroundStyle(Theme.textMuted)
                }
                Spacer()
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat("XP",     "\(app.xp)",          icon: "bolt.fill",   tone: Theme.accent)
            stat("Streak", "\(app.streakDays)",  icon: "flame.fill",  tone: Theme.coral)
            stat("Aura",   "\(app.aura)",        icon: "sparkles",    tone: Theme.aura)
        }
    }

    private func stat(_ label: String, _ value: String, icon: String, tone: Color) -> some View {
        GlassCard(padding: 14) {
            VStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tone)
                Text(value).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.text)
                Text(label).font(.system(size: 11, weight: .bold)).tracking(1.4)
                    .foregroundStyle(Theme.textMuted).textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var upgradeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: app.isPro ? "Membership" : "Charmster Pro",
                              systemImage: "crown.fill")
                if app.isPro {
                    Text(proStatusBlurb)
                        .font(.system(size: 14)).foregroundStyle(Theme.text)
                    GlassButton(title: "Manage membership", systemImage: "gearshape.fill") {
                        goToSettings = true
                    }
                } else {
                    Text("Unlock unlimited practice, capstones, and every persona.")
                        .font(.system(size: 14)).foregroundStyle(Theme.text)
                    AuraButton(title: "See membership options", systemImage: "sparkles") {
                        CharmsterSuperwall.register(.upgradePrompt)
                    }
                }
            }
        }
    }

    private var proStatusBlurb: String {
        switch app.subscriptionStatus {
        case .trial:
            if let end = app.trialEndsAt {
                let days = Calendar.current.dateComponents([.day], from: .now, to: end).day ?? 0
                return "Pro trial — \(max(0, days)) days left."
            }
            return "Pro trial active."
        case .pro:     return "Pro · \(app.subscriptionPlan.rawValue.capitalized)"
        case .expired: return "Pro expired. Re-subscribe to keep capstones."
        case .locked:  return "Free plan."
        }
    }

    private var pillsRow: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Defaults", systemImage: "slider.horizontal.3")
                HStack {
                    TagPill(label: "Tier: \(app.difficultyTier.title)",
                            systemImage: "flame.fill",
                            tone: .accent,
                            onTap: { goToSettings = true })
                    TagPill(label: "Coach: \(app.coachMode.title)",
                            systemImage: app.coachMode.icon,
                            tone: .gold,
                            onTap: { goToSettings = true })
                    Spacer()
                }
            }
        }
    }

    private var recentResultsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Recent sessions", systemImage: "clock.arrow.circlepath")
                if app.recentResults.isEmpty {
                    Text("No sessions yet. Start your first quest.")
                        .font(.system(size: 13)).foregroundStyle(Theme.textMuted)
                } else {
                    ForEach(app.recentResults.prefix(5)) { r in
                        HStack {
                            ScoreRing(value: r.sessionScore, size: 44, lineWidth: 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Curriculum.lecture(id: r.lectureId ?? "")?.title ?? "Sandbox")
                                    .font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.text)
                                Text(r.createdAt.formatted(.relative(presentation: .named)))
                                    .font(.system(size: 11)).foregroundStyle(Theme.textMuted)
                            }
                            Spacer()
                            Text("+\(r.xpEarned) XP").font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView().environment(AppState.preview)
}
