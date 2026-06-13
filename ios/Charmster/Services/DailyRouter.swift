import Foundation

/// The daily session router. Produces ONE prescribed session per day in spec
/// priority order, reusing the EXISTING engines (progression, SM-2 spaced rep,
/// the curriculum/scenario bank, the weekly drop) — never a parallel system.
///
/// 1) Next due lecture in the active path  → Path step (lecture + practice)
/// 2) Else a decaying / low-scored mastered skill (spaced-rep) → Daily Drill
/// 3) Else an unseen "New this week" drop  → featured scenario
/// 4) Else a Gold-tier stretch on a strong skill
///
/// The router is pure read logic over `AppState`; the Today hero renders its
/// output and launches the existing `LectureDetailSheet` for the chosen lecture.
enum DailyRouter {

  enum Kind {
    case pathStep
    case dailyDrill
    case weeklyDrop
    case goldStretch
  }

  struct Prescription {
    let kind: Kind
    let lecture: Lecture
    /// Difficulty auto-filled from the user's recommended defaults.
    let tier: DifficultyTier
    /// Short, human, coach-voiced framing for the Today hero.
    let headline: String
    let subline: String
    let ctaTitle: String

    var systemImage: String {
      switch kind {
      case .pathStep: return "play.fill"
      case .dailyDrill: return "arrow.triangle.2.circlepath"
      case .weeklyDrop: return "sparkles"
      case .goldStretch: return "crown.fill"
      }
    }
  }

  /// Resolve today's single prescribed session. Returns `nil` only when the
  /// curriculum is empty (never in normal operation).
  static func prescribe(for app: AppState) -> Prescription? {
    let coachName = app.selectedCoach.humanName

    // 1) Next due lecture in the active path.
    if let lec = nextPathStep(app: app) {
      return Prescription(
        kind: .pathStep,
        lecture: lec,
        tier: app.difficultyTier,
        headline: "Today: \(lec.title)",
        subline: "\(coachName) queued your next step on the path.",
        ctaTitle: "Start today's session")
    }

    // 2) A decaying / low-scored mastered skill (spaced rep). A fresh Scenario
    //    Bank variant of that weak skill = a Daily Drill rep.
    if let lec = weakestDueSkill(app: app) {
      return Prescription(
        kind: .dailyDrill,
        lecture: lec,
        tier: app.difficultyTier,
        headline: "Daily Drill: \(lec.skill)",
        subline: "\(coachName) wants a quick rep — this one's slipping.",
        ctaTitle: "Run the drill")
    }

    // 3) An unseen "New this week" drop.
    if let drop = WeeklyDrop.current(for: app), !WeeklyDrop.hasSeen(drop, app: app) {
      return Prescription(
        kind: .weeklyDrop,
        lecture: drop.lecture,
        tier: app.difficultyTier,
        headline: "New this week: \(drop.theme)",
        subline: "\(coachName) picked something fresh for you.",
        ctaTitle: "Try this week's drop")
    }

    // 4) Gold-tier stretch on a strong skill.
    if let lec = goldStretch(app: app) {
      return Prescription(
        kind: .goldStretch,
        lecture: lec,
        tier: .gold,
        headline: "Stretch: \(lec.skill)",
        subline: "You're ahead — \(coachName) lined up a Gold-tier challenge.",
        ctaTitle: "Take the stretch")
    }

    // Absolute fallback: the recommended start opener (keeps the hero alive).
    if let lec = app.tasterLecture {
      return Prescription(
        kind: .pathStep,
        lecture: lec,
        tier: app.difficultyTier,
        headline: "Today: \(lec.title)",
        subline: "\(coachName) is ready when you are.",
        ctaTitle: "Start today's session")
    }
    return nil
  }

  // MARK: - Stage resolvers

  /// The first `current` lecture in the user's recommended track, else the
  /// first `current` lecture overall.
  static func nextPathStep(app: AppState) -> Lecture? {
    let recommended = app.recommendedStartTrack.id
    if let lec = Curriculum.lectures(in: recommended).first(where: {
      app.state(of: $0) == .current
    }) {
      return lec
    }
    return Curriculum.lectures.first(where: { app.state(of: $0) == .current })
  }

  /// The most-overdue mastered skill whose SM-2 review is due — the one
  /// "decaying" fastest. Reuses `AppState.dueReviews`.
  static func weakestDueSkill(app: AppState) -> Lecture? {
    let due = app.dueReviews
    guard !due.isEmpty else { return nil }
    return
      due
      .sorted { a, b in
        let da = app.progress[a.id]?.dueAt ?? .distantFuture
        let db = app.progress[b.id]?.dueAt ?? .distantFuture
        return da < db
      }
      .first
  }

  /// A mastered (strong) lecture to push to the next tier as a stretch.
  static func goldStretch(app: AppState) -> Lecture? {
    Curriculum.lectures.first { lec in
      guard let p = app.progress[lec.id] else { return false }
      return p.mastery == .silver || p.mastery == .gold
    }
  }
}
