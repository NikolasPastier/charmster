import SwiftUI

struct ProfileView: View {
  @Environment(AppState.self) private var app
  @State private var goToSettings: Bool = false
  @State private var goToJournal: Bool = false
  @State private var showCoachGallery: Bool = false

  var body: some View {
    Group {
      NavigationStack {
        ScrollView {
          VStack(spacing: 14) {
            headerCard
            statsRow
            journalCard
            upgradeCard
            pillsRow
            recentResultsCard
          }
          .padding(18)
        }
        .background(AuraBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToSettings) {
          SettingsView()
        }
        .navigationDestination(isPresented: $goToJournal) {
          JournalView()
        }
      }
    }
    .trackView("ProfileView")
  }

  private var headerCard: some View {
    GlassCard {
      HStack(spacing: 14) {
        UserAvatarView(
          name: app.profile.name,
          photoPath: app.profile.profilePhotoPath,
          size: 54
        )
        VStack(alignment: .leading, spacing: 4) {
          Text(app.profile.name.isEmpty ? "Charmster" : app.profile.name)
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(Theme.text)
          Text("\(AuraTier.forAura(app.aura).title) · \(app.profile.attachmentLabel)")
            .font(.system(size: 13)).foregroundStyle(Theme.textMuted)
        }
        Spacer()
      }
    }
  }

  private var statsRow: some View {
    HStack(spacing: 10) {
      stat("Aura", "\(app.aura)", icon: "sparkles", tone: Theme.aura)
      stat("Streak", "\(app.streakDays)", icon: "flame.fill", tone: Theme.coral)
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

  private var journalCard: some View {
    Button {
      goToJournal = true
    } label: {
      GlassCard {
        HStack(spacing: 12) {
          Image(systemName: "chart.line.uptrend.xyaxis")
            .font(.system(size: 18, weight: .heavy))
            .foregroundStyle(Theme.aura)
            .frame(width: 38, height: 38)
            .background(Circle().fill(Theme.aura.opacity(0.14)))
          VStack(alignment: .leading, spacing: 2) {
            Text("Progress Journal")
              .font(.system(size: 16, weight: .heavy))
              .foregroundStyle(Theme.text)
            Text(journalSubtitle)
              .font(.system(size: 12))
              .foregroundStyle(Theme.textMuted)
          }
          Spacer()
          Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
        }
      }
    }
    .buttonStyle(.plain)
  }

  private var journalSubtitle: String {
    if app.journal.isEmpty {
      return "Trends, deltas, and personal bests after your first session"
    }
    return "\(app.journal.count) session\(app.journal.count == 1 ? "" : "s") logged · trends & PRs"
  }

  private var upgradeCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        SectionHeader(
          title: app.isPro ? "Membership" : "Charmster Pro",
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
    case .pro: return "Pro · \(app.subscriptionPlan.rawValue.capitalized)"
    case .expired: return "Pro expired. Re-subscribe to keep capstones."
    case .locked: return "Free plan."
    }
  }

  private var pillsRow: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 12) {
        SectionHeader(title: "Your coach", systemImage: "person.crop.circle.badge.checkmark")
        Button {
          showCoachGallery = true
        } label: {
          HStack(spacing: 12) {
            CoachAvatarView(coach: app.selectedCoach)
              .frame(width: 52, height: 52)
              .clipShape(Circle())
              .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
              Text(app.selectedCoach.humanName)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Theme.text)
              Text("Tap to switch coach")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
          }
        }
        .buttonStyle(.plain)
        HStack {
          TagPill(
            label: "Tier: \(app.difficultyTier.title)",
            systemImage: "flame.fill",
            tone: .accent,
            onTap: { goToSettings = true })
          Spacer()
        }
      }
    }
    .sheet(isPresented: $showCoachGallery) {
      CoachGalleryView().environment(app)
        .appThemedPresentation()
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
              Text(auraDeltaLabel(r.auraEarned))
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(r.auraEarned >= 0 ? Theme.aura : Theme.coral)
            }
          }
        }
      }
    }
  }
  private func auraDeltaLabel(_ d: Int) -> String {
    if d > 0 { return "+\(d) Aura" }
    if d < 0 { return "\(d) Aura" }
    return "Aura held"
  }
}

#Preview {
  ProfileView().environment(AppState.preview)
}
