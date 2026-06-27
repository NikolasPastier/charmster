import SwiftUI

/// The home / Path tab. A TODAY hero card sits at the very top: the coach +
/// ONE prescribed session (from `DailyRouter`) + the streak — no browsing
/// required. Below it: the weekly drop shelf, then the Duolingo-style path.
struct RoadmapView: View {
  @Environment(AppState.self) private var app
  @State private var presentedLecture: Lecture?
  @State private var lockHint: LockHint?

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
        .background(AuraBackground())
        .toolbarVisibility(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
          HStack {
            StatPill(systemImage: "flame.fill", value: app.streakDays, tint: Theme.coral)
            Spacer()
            StatPill(systemImage: "sparkles", value: app.aura, tint: Theme.aura)
          }
          .padding(.horizontal, 18)
          .padding(.vertical, 8)
        }
      }
      .sheet(item: $presentedLecture) { lec in
        LectureDetailSheet(lecture: lec)
          .environment(app)
          .presentationDetents([.large])
          .presentationDragIndicator(.visible)
          .appThemedPresentation()
      }
      .alert(item: $lockHint) { hint in
        Alert(
          title: Text(hint.title),
          message: Text(hint.message),
          dismissButton: .default(Text("Got it")))
      }
    }
    .trackView("RoadmapView")
  }

  // MARK: - Tap routing

  /// Locked lectures don't hard-fail: tapping one surfaces a brief, encouraging
  /// hint about what to finish first. Pro-gated lectures route to Superwall.
  /// Everything else opens the lecture sheet (completed lectures included — a
  /// completed lecture is always replayable).
  private func handleTap(_ lecture: Lecture) {
    let state = effectiveState(for: lecture)
    switch state {
    case .locked, .capstoneLocked:
      if !app.isPro, lecture.access == .pro, app.isUnlocked(lecture) {
        CharmsterSuperwall.register(.upgradePrompt)
        return
      }
      if let prereq = app.unlockPrerequisite(for: lecture) {
        lockHint = LockHint(
          title: "Keep going",
          message: "Finish “\(prereq.title)” to unlock this lecture.")
      } else {
        lockHint = LockHint(
          title: "Locked",
          message: "This lecture isn't available just yet.")
      }
    default:
      presentedLecture = lecture
    }
  }

  // MARK: - Today hero

  @ViewBuilder
  private var todayHero: some View {
    if let rx = DailyRouter.prescribe(for: app) {
      TodayHeroCard(prescription: rx, coach: app.selectedCoach) {
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
              onTap: { handleTap(lec) }
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
    // LEC3.1: Each track's first lecture is always accessible so users can enter
    // any section regardless of subscription tier.
    let firstInTrack = Curriculum.lectures(in: lecture.trackId).first(where: { !$0.isCapstone })
    if firstInTrack?.id == lecture.id { return base }
    switch base {
    case .mastered, .capstoneMastered: return base
    case .capstoneLocked, .capstoneAvailable: return .capstoneLocked
    default: return .locked
    }
  }
}

// MARK: - Toolbar stat pill

/// A compact, symmetrical header pill: a circular tinted icon plus a count,
/// laid out as one HStack so the icon and number stay vertically centered and
/// never clip. The number shrinks-to-fit so 2-3 digit counts still fit cleanly.
private struct StatPill: View {
  let systemImage: String
  let value: Int
  let tint: Color

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: systemImage)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(tint)
        .frame(width: 18, height: 18)
      Text("\(value)")
        .font(.system(size: 14, weight: .heavy))
        .foregroundStyle(Theme.text)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .fixedSize()
    }
    .padding(.horizontal, 11)
    .frame(height: 30)
    .background(
      Capsule(style: .continuous).fill(Theme.surfaceRaised)
    )
    .overlay(
      Capsule(style: .continuous).stroke(Theme.border, lineWidth: 1)
    )
  }
}

// MARK: - Today hero card

struct TodayHeroCard: View {
  @Environment(AppState.self) private var app
  let prescription: DailyRouter.Prescription
  let coach: CoachPersona
  let onStart: () -> Void

  var body: some View {
    GlassCard {
      if app.dailyCompleted {
        completedBody
      } else {
        activeBody
      }
    }
  }

  // MARK: Active (not yet done today)

  private var activeBody: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        CoachAvatarView(coach: coach)
          .frame(width: 56, height: 56)
          .clipShape(Circle())
          .overlay(Circle().stroke(Theme.accent.opacity(0.4), lineWidth: 1))
          .auraGlow()
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
        Spacer()
      }

      AuraButton(
        title: prescription.ctaTitle, systemImage: prescription.systemImage, action: onStart)
    }
  }

  // MARK: Completed (session done today)

  private var completedBody: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        CoachAvatarView(coach: coach)
          .frame(width: 56, height: 56)
          .clipShape(Circle())
          .overlay(Circle().stroke(Theme.accent.opacity(0.4), lineWidth: 1))
          .auraGlow()
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 5) {
            Text("TODAY")
              .font(.system(size: 11, weight: .heavy)).tracking(2.0)
              .foregroundStyle(Theme.accent)
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 11, weight: .heavy))
              .foregroundStyle(Theme.accent)
          }
          Text("Session complete")
            .font(.system(size: 19, weight: .heavy))
            .foregroundStyle(Theme.text)
        }
        Spacer()
      }

      Text(prescription.headline)
        .font(.system(size: 14))
        .foregroundStyle(Theme.textMuted)
        .lineLimit(2)

      // Recap: score + aura from most-recent result, plus streak count.
      HStack(spacing: 16) {
        if let r = app.recentResults.first {
          Label("\(r.sessionScore)", systemImage: "chart.bar.fill")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Theme.scoreColor(for: r.sessionScore))
          let sign = r.auraEarned >= 0 ? "+" : ""
          Label("\(sign)\(r.auraEarned) Aura", systemImage: "sparkles")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Theme.aura)
        }
        Label("\(app.streakDays) day streak", systemImage: "flame.fill")
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(Theme.coral)
      }

      // Secondary CTA — same action, reduced visual weight.
      Button(action: onStart) {
        HStack(spacing: 8) {
          Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 14, weight: .heavy))
          Text("Practice again")
            .font(.system(size: 15, weight: .heavy))
        }
        .foregroundStyle(Theme.textMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
          RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
            .fill(Theme.surfaceRaised))
        .overlay(
          RoundedRectangle(cornerRadius: Theme.r12, style: .continuous)
            .stroke(Theme.border, lineWidth: 1))
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - Weekly drop shelf

struct WeeklyDropShelf: View {
  @Environment(AppState.self) private var app
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
            let isCompleted = !locked && (app.progress[lec.id]?.practiced == true)
            WeeklyDropTile(lecture: lec, locked: locked, isCompleted: isCompleted) {
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
  let isCompleted: Bool
  let onTap: () -> Void

  private var iconName: String {
    if locked { return "lock.fill" }
    if isCompleted { return "checkmark.circle.fill" }
    return "sparkles"
  }

  private var iconColor: Color {
    if locked { return Theme.textMuted }
    if isCompleted { return Theme.accent }
    return .white
  }

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: Theme.r16, style: .continuous)
            .fill(Theme.surfaceRaised)
            .frame(height: 84)
          Theme.auraGradient.opacity(isCompleted ? 0.10 : 0.25)
            .clipShape(RoundedRectangle(cornerRadius: Theme.r16, style: .continuous))
            .frame(height: 84)
          Image(systemName: iconName)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(iconColor)
        }
        Text(lecture.title)
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(isCompleted ? Theme.textMuted : Theme.text)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        Text(isCompleted ? "Completed" : lecture.skill)
          .font(.system(size: 11))
          .foregroundStyle(isCompleted ? Theme.accent.opacity(0.7) : Theme.textMuted)
          .lineLimit(1)
      }
      .frame(width: 150)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Lock hint

/// Lightweight, non-punishing message shown when a user taps a locked lecture.
struct LockHint: Identifiable {
  let id = UUID()
  let title: String
  let message: String
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
    case .locked, .capstoneLocked: return Theme.textMuted
    case .current, .mastered: return Theme.accent
    case .capstoneAvailable: return .black
    case .capstoneMastered: return Theme.gold
    }
  }
}

#Preview {
  RoadmapView().environment(AppState.preview)
}
