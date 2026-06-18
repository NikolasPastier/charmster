import Foundation

/// Weekly fresh content drop (spec P7). Each ISO week surfaces ONE curated
/// pick from the Scenario Bank (a theme + a featured lecture), deterministically
/// rotated so it's stable for the whole week and changes every Monday. This is
/// zero-decision curated novelty — distinct from the Sandbox (on-demand, full
/// control).
///
/// Source: rotates existing curriculum/Scenario Bank variants, respecting the
/// user's active track + tier. When the Content Engine pipeline is available it
/// can replace `pickLecture` (science-gated) without touching callers.
///
/// Pro gating (locked decision): free users get a TASTE (the featured drop is
/// previewable but the full themed pack is Pro). Reuses existing `app.isPro`.
struct WeeklyDrop: Hashable {
  let weekKey: String
  let theme: String
  let lecture: Lecture
  /// The wider themed set (the "full pack"). First item is the free taste.
  let pack: [Lecture]

  // Curated weekly themes, rotated by week index.
  private static let themes: [String] = [
    "Confident openers",
    "Playful banter",
    "Reading interest",
    "Deeper questions",
    "Recovering after a stumble",
    "Vocal presence",
    "Holding a calm frame",
    "Closing with intention",
  ]

  /// Stable ISO week key, e.g. "2026-W24".
  static func currentWeekKey(_ date: Date = .now) -> String {
    let cal = Calendar(identifier: .iso8601)
    let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return "\(comps.yearForWeekOfYear ?? 0)-W\(comps.weekOfYear ?? 0)"
  }

  private static func weekIndex(_ date: Date = .now) -> Int {
    let cal = Calendar(identifier: .iso8601)
    let woy = cal.component(.weekOfYear, from: date)
    let yr = cal.component(.yearForWeekOfYear, from: date)
    return yr * 53 + woy
  }

  /// This week's curated drop for the user, or `nil` if the curriculum is empty.
  static func current(for app: AppState, date: Date = .now) -> WeeklyDrop? {
    let idx = weekIndex(date)
    let theme = themes[idx % themes.count]

    // Prefer lectures from the user's recommended track; fall back to all.
    let trackId = app.recommendedStartTrack.id
    var pool = Curriculum.lectures(in: trackId).filter { !$0.isCapstone }
    if pool.count < 3 {
      pool = Curriculum.lectures.filter { !$0.isCapstone }
    }
    guard !pool.isEmpty else { return nil }

    // Deterministic rotation within the pool so the pick is stable all week.
    let start = (idx * 3) % pool.count
    var pack: [Lecture] = []
    for offset in 0..<min(4, pool.count) {
      pack.append(pool[(start + offset) % pool.count])
    }
    guard let featured = pack.first else { return nil }

    return WeeklyDrop(
      weekKey: currentWeekKey(date), theme: theme, lecture: featured, pack: pack)
  }

  // MARK: - Seen tracking (UserDefaults; zero new model surface)

  private static let seenKey = "charmster.weeklyDrop.seen.v1"

  static func hasSeen(_ drop: WeeklyDrop, app: AppState) -> Bool {
    UserDefaults.standard.string(forKey: seenKey) == drop.weekKey
  }

  static func markSeen(_ drop: WeeklyDrop) {
    UserDefaults.standard.set(drop.weekKey, forKey: seenKey)
  }

  /// Free users get the featured taste; the rest of the pack is Pro.
  static func freeTaste(of drop: WeeklyDrop, isPro: Bool) -> [Lecture] {
    isPro ? drop.pack : [drop.lecture]
  }

  static func lockedCount(of drop: WeeklyDrop, isPro: Bool) -> Int {
    isPro ? 0 : max(0, drop.pack.count - 1)
  }
}
