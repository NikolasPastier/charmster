import Foundation

/// Thin UserDefaults-backed JSON store for the settings that the Settings
/// screen lets the user edit. The runtime models stay in `AppState`; this
/// store only handles encode/decode + change persistence so prefs survive
/// across launches.
///
/// We deliberately do NOT touch progress, aura, streaks, or subscription
/// state — those have their own lifecycles (and progress would normally be
/// reconciled against Supabase). This is strictly for the prefs that Settings
/// controls write.
enum SettingsStore {

  private static let profileKey = "charmster.profile.v1"
  private static let coachKey = "charmster.coachMode.v1"
  private static let tierKey = "charmster.difficultyTier.v1"
  private static let streakFreezeKey = "charmster.streakFreezes.v1"
  private static let lastFreezeRefillKey = "charmster.lastFreezeRefill.v1"

  // MARK: - Profile

  static func loadProfile() -> PersonalizationProfile? {
    guard let data = UserDefaults.standard.data(forKey: profileKey) else { return nil }
    return try? JSONDecoder().decode(PersonalizationProfile.self, from: data)
  }

  static func saveProfile(_ profile: PersonalizationProfile) {
    guard let data = try? JSONEncoder().encode(profile) else { return }
    UserDefaults.standard.set(data, forKey: profileKey)
  }

  // MARK: - Coach + difficulty

  static func loadCoach() -> CoachStyle? {
    UserDefaults.standard.string(forKey: coachKey).flatMap(CoachStyle.init(rawValue:))
  }

  static func saveCoach(_ coach: CoachStyle) {
    UserDefaults.standard.set(coach.rawValue, forKey: coachKey)
  }

  static func loadTier() -> DifficultyTier? {
    UserDefaults.standard.string(forKey: tierKey).flatMap(DifficultyTier.init(rawValue:))
  }

  static func saveTier(_ tier: DifficultyTier) {
    UserDefaults.standard.set(tier.rawValue, forKey: tierKey)
  }

  // MARK: - Streak freezes

  static func loadStreakFreezes() -> Int? {
    let v = UserDefaults.standard.object(forKey: streakFreezeKey) as? Int
    return v
  }

  static func saveStreakFreezes(_ count: Int) {
    UserDefaults.standard.set(count, forKey: streakFreezeKey)
  }

  static func loadLastFreezeRefill() -> Date? {
    UserDefaults.standard.object(forKey: lastFreezeRefillKey) as? Date
  }

  static func saveLastFreezeRefill(_ date: Date) {
    UserDefaults.standard.set(date, forKey: lastFreezeRefillKey)
  }

  // MARK: - Wipe (used by deleteAccount)

  static func wipeAll() {
    let d = UserDefaults.standard
    [profileKey, coachKey, tierKey, streakFreezeKey, lastFreezeRefillKey].forEach {
      d.removeObject(forKey: $0)
    }
  }
}
