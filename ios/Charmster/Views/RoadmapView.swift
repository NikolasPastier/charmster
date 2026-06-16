import SwiftUI

/// The home / Path tab. A TODAY hero card sits at the very top: the coach +
/// ONE prescribed session (from `DailyRouter`) + the streak — no browsing
/// required. Below it: the weekly drop shelf, then the Duolingo-style path.
struct RoadmapView: View {
  @Environment(AppState.self) private var app
  @State private var presentedLecture: Lecture?

  var body: some View {
    Group {
      NavigationStack {
        ScrollView {
          VStack(spacing: 28) {
            todayHero
            weeklyShelf
            ForEach(Curriculum.tracks) { track in
              trackSection(track: track)
            }
          }
          .padding(.horizontal, 18)
          .padding(.vertical, 18)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Your path")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .principal) {
            CharmsterLogo(height: 26)
              .frame(maxWidth: 150)
          }
          ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 6) {
              Image(systemName: "flame.fill").foregroundStyle(Theme.coral)
              Text("\(app.streakDays)").font(.system(size: 14, weight: .heavy))
            }
          }
          ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 6) {
              Image(systemName: "sparkles").foregroundStyle(Theme.aura)
              Text("\(app.aura)").font(.system(size: 14, weight: .heavy))
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

  // MARK: - Today hero

  @ViewBuilder
  private var todayHero: some View {
    if let rx = DailyRouter.prescribe(for: app) {
      TodayHeroCard(prescription: rx, streak: app.streakDays, coach: app.selectedCoach) {
        if rx.kind == .weeklyDrop, let drop = WeeklyDrop.current(for: app) {
          WeeklyDrop.markSeen(drop)
        }
        presentedLecture = rx.lecture
      }
    }
  }

  // MARK: - Weekly drop shelf

  @ViewBuilder
  private var weeklyShelf: some View {
    if let drop = WeeklyDrop.current(for: app) {
      WeeklyDropShelf(
        drop: drop,
        isPro: app.isPro,
        onOpen: { lec in presentedLecture = lec },
        onUpgrade: { CharmsterSuperwall.register(.upgradePrompt) }
      )
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
              state: effectiveState(for: lec),
              onTap: { presentedLecture = lec }
            )
            if !idx.isMultiple(of: 2) { Spacer() }
          }
        }
      }
    }
  }

  /// Apply access-tier gating on top of progression state. Pro-only lectures
  /// render as locked when the user isn't on a paid tier; the lecture sheet
  /// then routes them through Superwall.
  private func effectiveState(for lecture: Lecture) -> LectureState {
    let base = app.state(of: lecture)
    guard !app.isPro, lecture.access == .pro else { return base }
    switch base {
    case .mastered, .capstoneMastered: return base
    case .capstoneLocked, .capstoneAvailable: return .capstoneLocked
    default: return .locked
    }
  }
}

// MARK: - Today hero card

struct TodayHeroCard: View {
  let prescription: DailyRouter.Prescription
  let streak: Int
  let coach: CoachPersona
  let onStart: () -> Void

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
          CoachAvatarView(coach: coach)
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.accent.opacity(0.4), lineWidth: 1))
          VStack(alignment: .leading, spacing: 2) {
            Text("TODAY")
              .font(.system(size: 11, weight: .heavy)).tracking(2.0)
              .foregroundStyle(Theme.accent)
            Text(prescription.headline)
              .font(.system(size: 19, weight: .heavy))
              .foregroundStyle(Theme.text)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
        }

        Text(prescription.subline)
          .font(.system(size: 14))
          .foregroundStyle(Theme.textMuted)

        HStack(spacing: 8) {
          TagPill(label: prescription.tier.title, systemImage: "flame.fill", tone: .accent)
          TagPill(label: "🔥 \(streak)-day streak", tone: .coral)
          Spacer()
        }

        AuraButton(
          title: prescription.ctaTitle, systemImage: prescription.systemImage, action: onStart)
      }
    }
  }
}

// MARK: - Weekly drop shelf

struct WeeklyDropShelf: View {
  let drop: WeeklyDrop
  let isPro: Bool
  let onOpen: (Lecture) -> Void
  let onUpgrade: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "New this week", subtitle: drop.theme, systemImage: "sparkles")
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(Array(drop.pack.enumerated()), id: \.element.id) { idx, lec in
            let locked = !isPro && idx > 0
            WeeklyDropTile(lecture: lec, locked: locked) {
              if locked { onUpgrade() } else { onOpen(lec) }
            }
          }
        }
        .padding(.horizontal, 2)
      }
      if !isPro {
        Text("You get this week's first drop free. Pro unlocks the full pack.")
          .font(.system(size: 12))
          .foregroundStyle(Theme.textMuted)
      }
    }
  }
}

private struct WeeklyDropTile: View {
  let lecture: Lecture
  let locked: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
            .fill(Theme.surfaceRaised)
            .frame(height: 84)
          Theme.auraGradient.opacity(0.25)
            .clipShape(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous))
            .frame(height: 84)
          Image(systemName: locked ? "lock.fill" : "sparkles")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(locked ? Theme.textFaint : .white)
        }
        Text(lecture.title)
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(Theme.text)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        Text(lecture.skill)
          .font(.system(size: 11))
          .foregroundStyle(Theme.textMuted)
          .lineLimit(1)
      }
      .frame(width: 150)
    }
    .buttonStyle(.plain)
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
          if state == .mastered || state == .capstoneMastered {
            replayBadge
          }
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

  /// Small replay glyph on completed (mastered) nodes so the path makes it
  /// clear a finished lecture can be replayed with different settings.
  private var replayBadge: some View {
    VStack {
      HStack {
        Spacer()
        Image(systemName: "arrow.counterclockwise.circle.fill")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(Theme.accent)
          .background(Circle().fill(Theme.bg))
          .offset(x: 6, y: -4)
      }
      Spacer()
    }
    .frame(width: lecture.isCapstone ? 108 : 76, height: lecture.isCapstone ? 108 : 76)
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
