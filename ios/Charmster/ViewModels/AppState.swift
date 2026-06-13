import Foundation
import Observation
import SwiftUI

// MARK: - Subscription

enum SubscriptionStatus: String, Codable {
  case locked
  case trial
  case pro
  case expired
}

enum SubscriptionPlan: String, Codable {
  case none
  case monthly
  case yearly
}

// MARK: - Personalization

struct PersonalizationProfile: Codable {
  var name: String = ""
  var goal: String = "Date with intention"
  var experience: String = "Some experience"
  var flirtingStyle: String = "Warm"
  var confidence: Int = 5
  var focusAreas: Set<String> = ["Opening", "Flow"]
  var attachmentAnxiety: Double = 0.4
  var attachmentAvoidance: Double = 0.3
  var attachmentLabel: String = "Secure-leaning"
  /// Raw 1–5 answers to the 6-item attachment check-in, in spec order:
  /// 0–2 anxiety items, 3–5 avoidance items. Empty until the user completes
  /// (or skips, which keeps the secure-leaning defaults) that step.
  var attachmentAnswers: [Int] = []
  var feedbackGentleness: Double = 0.5  // 0 direct .. 1 gentle (auto-set, manually overridable)
  // Avatar look picked in onboarding (Step 4). Defaults to Mia.
  var avatarLookId: String = "mia"
  var avatarName: String = "Mia"
  // Account + age gate (Step 6 / 11). 17+ confirmed once, timestamped.
  var username: String = ""
  var ageConfirmed17: Bool = false
  var ageConfirmedAt: Date? = nil
  var dailyGoalMinutes: Int = 10
  var dailyReminderTime: Date? = nil
  var practiceModeDefault: PracticeMode = .videoVoice
  var prefersTextPractice: Bool = false
  var quietHoursStart: Date? = nil
  var quietHoursEnd: Date? = nil
  var analyticsOptIn: Bool = true
  var captionsEnabled: Bool = true
  var soundAndHaptics: Bool = true
  var notificationsStreak: Bool = true
  var notificationsDailyChallenge: Bool = true
  var notificationsNewContent: Bool = true
  var notificationsReengagement: Bool = false
  var emailDigest: Bool = false
  var emailProduct: Bool = false
  var emailMarketing: Bool = false
  var themePreference: String = "system"  // system | light | dark
  var textSize: String = "standard"  // standard | large
}

// MARK: - Lecture state (for roadmap)

enum LectureState {
  case locked
  case current
  case mastered
  case capstoneLocked
  case capstoneAvailable
  case capstoneMastered
}

// MARK: - AppState

@Observable
final class AppState {

  // Identity
  var userId: String = "preview-user"
  var hasCompletedOnboarding: Bool = false

  // Personalization
  var profile = PersonalizationProfile()

  // Coaching defaults
  var coachMode: CoachStyle = .wingman
  var difficultyTier: DifficultyTier = .silver
  var selectedPersona: PartnerPersona = .default
  var selectedSetting: PracticeSetting = .default

  // Progress
  var progress: [String: LectureProgress] = [:]
  var aura: Int = 0
  var streakDays: Int = 0
  var lastActiveDay: Date?

  // Daily Charge
  var chargeCap: Int = 3
  var chargeMinutes: Int = 0
  var dailyLiveSessionsUsed: Int = 0
  var sandboxUsedToday: Bool = false
  var dailyResetAt: Date = .now

  // Streak freezes (monthly allowance of "rest day" protections)
  var streakFreezesRemaining: Int = 2
  var streakFreezeMonthlyAllowance: Int = 2
  var lastStreakFreezeRefill: Date = .distantPast

  // Subscription
  var subscriptionStatus: SubscriptionStatus = .locked
  var subscriptionPlan: SubscriptionPlan = .none
  var trialStartedAt: Date?
  var trialEndsAt: Date?
  var cancelReason: String?
  var saveOfferClaimedAt: Date?

  // Coins (disabled feature flag — kept for data integrity)
  var coinsEnabled: Bool = false

  // Recent session history (for review hub)
  var recentResults: [SessionResult] = []

  // MARK: - Lifecycle

  func bootstrap() async {
    // Restore persisted prefs first so progress migration / daily reset use them.
    loadPersistedPrefs()
    refillStreakFreezesIfNeeded()
    migrateLegacyProgressKeysIfNeeded()
    await CurriculumService.shared.refreshIfNeeded()
    // Seed locked/current state — first lecture of track 0 is current.
    if progress.isEmpty {
      if let first = Curriculum.lectures.first {
        progress[first.id] = LectureProgress()
      }
    }
    rollDailyResetIfNeeded()
  }

  // MARK: - Persistence

  /// Pull saved Settings prefs from `SettingsStore` into the runtime model.
  private func loadPersistedPrefs() {
    if let saved = SettingsStore.loadProfile() { profile = saved }
    if let coach = SettingsStore.loadCoach() { coachMode = coach }
    if let tier = SettingsStore.loadTier() { difficultyTier = tier }
    if let n = SettingsStore.loadStreakFreezes() { streakFreezesRemaining = n }
    if let d = SettingsStore.loadLastFreezeRefill() { lastStreakFreezeRefill = d }
  }

  /// Persist everything Settings can edit. Called by the Settings screen's
  /// binding helper on every mutation so changes survive across launches.
  func persistSettings() {
    SettingsStore.saveProfile(profile)
    SettingsStore.saveCoach(coachMode)
    SettingsStore.saveTier(difficultyTier)
    SettingsStore.saveStreakFreezes(streakFreezesRemaining)
    SettingsStore.saveLastFreezeRefill(lastStreakFreezeRefill)
  }

  /// Refill the monthly streak-freeze allowance on the first launch of a new
  /// calendar month. The first run after install also seeds the count.
  private func refillStreakFreezesIfNeeded() {
    let cal = Calendar.current
    let now = Date()
    let sameMonth = cal.isDate(lastStreakFreezeRefill, equalTo: now, toGranularity: .month)
    if !sameMonth {
      streakFreezesRemaining = streakFreezeMonthlyAllowance
      lastStreakFreezeRefill = now
      SettingsStore.saveStreakFreezes(streakFreezesRemaining)
      SettingsStore.saveLastFreezeRefill(lastStreakFreezeRefill)
    }
  }

  /// User-initiated: spend one freeze to protect the current streak today.
  /// Returns true on success. UI presents a confirm before calling this.
  @discardableResult
  func useStreakFreeze() -> Bool {
    guard streakFreezesRemaining > 0 else { return false }
    streakFreezesRemaining -= 1
    SettingsStore.saveStreakFreezes(streakFreezesRemaining)
    return true
  }

  /// One-time migration from the old "t{N}_l{N}" placeholder IDs to the
  /// canonical "<track>.<number>" scheme. Safe to call on every launch.
  private func migrateLegacyProgressKeysIfNeeded() {
    guard progress.keys.contains(where: { $0.hasPrefix("t") && $0.contains("_l") }) else { return }
    var migrated: [String: LectureProgress] = [:]
    for (key, value) in progress {
      if let newId = Curriculum.migrateLegacyLectureId(key) {
        // If both old + new exist, keep the more-progressed record.
        if let existing = migrated[newId], existing.isMastered { continue }
        migrated[newId] = value
      } else {
        migrated[key] = value
      }
    }
    progress = migrated
  }

  // MARK: - Derived

  var isPro: Bool {
    subscriptionStatus == .pro || subscriptionStatus == .trial
  }

  var hasAccess: Bool { isPro }

  var dailyLiveSessionsCap: Int {
    isPro ? 99 : chargeCap
  }

  var canStartLivePractice: Bool {
    rollDailyResetIfNeeded()
    return dailyLiveSessionsUsed < dailyLiveSessionsCap
  }

  func state(of lecture: Lecture) -> LectureState {
    let p = progress[lecture.id]
    if lecture.isCapstone {
      // Capstone unlocks once all non-capstone lectures in the track are mastered.
      let others = Curriculum.lectures(in: lecture.trackId).filter { !$0.isCapstone }
      let allMastered = others.allSatisfy { progress[$0.id]?.isMastered == true }
      if let p, p.isMastered { return .capstoneMastered }
      return allMastered ? .capstoneAvailable : .capstoneLocked
    }
    if let p, p.isMastered { return .mastered }
    if p != nil { return .current }
    // Sequential unlock: current if previous in track is mastered (or it's the first overall).
    let trackLectures = Curriculum.lectures(in: lecture.trackId).filter { !$0.isCapstone }
    if let idx = trackLectures.firstIndex(of: lecture) {
      if idx == 0 && lecture.trackId == 0 { return .current }
      if idx > 0, progress[trackLectures[idx - 1].id]?.isMastered == true { return .current }
      // Allow first lecture of a new track once the prior track's capstone is mastered.
      if idx == 0, lecture.trackId > 0,
        let prevCapstone = Curriculum.capstone(in: lecture.trackId - 1),
        progress[prevCapstone.id]?.isMastered == true
      {
        return .current
      }
    }
    return .locked
  }

  // MARK: - Progress mutations

  func recordWatched(_ lecture: Lecture) {
    var p = progress[lecture.id] ?? LectureProgress()
    p.watched = true
    progress[lecture.id] = p
  }

  func recordQuiz(_ lecture: Lecture, correct: Int) {
    var p = progress[lecture.id] ?? LectureProgress()
    p.quizCorrect = max(p.quizCorrect, correct)
    progress[lecture.id] = p
    maybePromoteMastery(lecture)
  }

  func completePractice(_ lecture: Lecture, result: SessionResult) {
    var p = progress[lecture.id] ?? LectureProgress()
    p.practiced = true
    p.lastPracticedAt = .now
    progress[lecture.id] = p
    applyRewards(result)
    recentResults.insert(result, at: 0)
    if recentResults.count > 40 { recentResults.removeLast(recentResults.count - 40) }
    maybePromoteMastery(lecture)
    scheduleSRSReview(for: lecture, quality: srsQuality(from: result))
    dailyLiveSessionsUsed += 1
  }

  func completeSandbox(result: SessionResult, scored: Bool) {
    applyRewards(result)
    recentResults.insert(result, at: 0)
    sandboxUsedToday = true
    if scored { dailyLiveSessionsUsed += 1 }
  }

  private func applyRewards(_ result: SessionResult) {
    // auraEarned is a signed delta produced by SessionScorer's EMA pull.
    // Aura itself is the 0–100 rolling average — clamp on apply.
    aura = max(0, min(100, aura + result.auraEarned))
    if result.streakKept { streakDays += 1 }
  }

  private func maybePromoteMastery(_ lecture: Lecture) {
    guard var p = progress[lecture.id] else { return }
    if p.practiced && p.quizCorrect >= 2 {
      if p.mastery == .none { p.mastery = .bronze }
    }
    progress[lecture.id] = p
  }

  // MARK: - SM-2 spaced repetition

  private func srsQuality(from r: SessionResult) -> Int {
    // Map session score -> SM-2 quality (0..5).
    switch r.sessionScore {
    case 90...: return 5
    case 80..<90: return 4
    case 70..<80: return 3
    case 60..<70: return 2
    case 50..<60: return 1
    default: return 0
    }
  }

  private func scheduleSRSReview(for lecture: Lecture, quality: Int) {
    guard var p = progress[lecture.id] else { return }
    if quality < 3 {
      p.srsRepetitions = 0
      p.srsIntervalDays = 1
    } else {
      p.srsRepetitions += 1
      switch p.srsRepetitions {
      case 1: p.srsIntervalDays = 3
      case 2: p.srsIntervalDays = 7
      case 3: p.srsIntervalDays = 14
      case 4: p.srsIntervalDays = 30
      default: p.srsIntervalDays = max(60, Int(Double(p.srsIntervalDays) * p.srsEase))
      }
      p.srsEase = max(
        1.3, p.srsEase + (0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02)))
    }
    p.dueAt = Calendar.current.date(byAdding: .day, value: p.srsIntervalDays, to: .now)
    progress[lecture.id] = p
  }

  /// Lectures whose `dueAt` has passed.
  var dueReviews: [Lecture] {
    let now = Date()
    return Curriculum.lectures.filter {
      guard let p = progress[$0.id], let due = p.dueAt else { return false }
      return due <= now && p.mastery != .none
    }
  }

  /// Called when a review session succeeds — bumps mastery tier.
  func recordReviewSuccess(_ lecture: Lecture, result: SessionResult) {
    guard var p = progress[lecture.id] else { return }
    p.mastery = p.mastery.advanced()
    p.lastPracticedAt = .now
    progress[lecture.id] = p
    scheduleSRSReview(for: lecture, quality: srsQuality(from: result))
    applyRewards(result)
    recentResults.insert(result, at: 0)
  }

  // MARK: - Personalization

  /// Goal → recommended starting track (per the onboarding spec). Track IDs map
  /// to `curriculum.json` content tracks (1–16). Editable later in Settings via
  /// `recomputePersonalization()`.
  static let goalToTrackId: [String: Int] = [
    "Date with intention": 7,  // Deep Connection & Emotional Intimacy
    "Date casually": 4,  // Humor, Playfulness & Banter
    "Get unstuck": 8,  // Confidence, Anxiety & Handling Rejection
    "Confidence in general": 6,  // Presence: Body Language & Vocal Charisma
  ]

  /// The track the personalized plan recommends the user starts in, derived
  /// from their Goal. Falls back to Track 1 (Foundations) if unmapped.
  var recommendedStartTrack: Track {
    let id = Self.goalToTrackId[profile.goal] ?? 1
    return Curriculum.tracks.first { $0.id == id }
      ?? Curriculum.tracks.first { $0.id == 1 }
      ?? Curriculum.tracks.first(where: { $0.id != 0 })
      ?? Curriculum.tracks.first!
  }

  /// One-line "why this fits you" copy for the recommended track.
  var recommendedStartReason: String {
    switch profile.goal {
    case "Date with intention":
      return "You want something real — so we start where chats turn into a bond."
    case "Date casually":
      return "Keeping it light is a skill. We start with playfulness and banter."
    case "Get unstuck":
      return "Let's quiet the inner critic first, so the rest gets easier."
    case "Confidence in general":
      return "Presence is the foundation. We build how you carry yourself first."
    default:
      return "We start with the fundamentals of why people actually click."
    }
  }

  func recomputePersonalization() {
    // Recompute attachment scores from the raw 6-item check-in if present.
    // Items 0–2 = anxiety, 3–5 = avoidance, each on a 1–5 scale.
    if profile.attachmentAnswers.count == 6 {
      let anxItems = profile.attachmentAnswers[0..<3]
      let avoItems = profile.attachmentAnswers[3..<6]
      let anx = Double(anxItems.reduce(0, +)) / 15.0  // 0..1
      let avo = Double(avoItems.reduce(0, +)) / 15.0  // 0..1
      profile.attachmentAnxiety = anx
      profile.attachmentAvoidance = avo
      profile.attachmentLabel = Self.attachmentLabel(anxiety: anx, avoidance: avo)
    }

    // Map confidence -> recommended tier.
    let conf = profile.confidence
    difficultyTier = conf >= 7 ? .gold : (conf >= 4 ? .silver : .bronze)
    profile.feedbackGentleness = min(
      1.0,
      max(
        0.0,
        0.4 + (profile.attachmentAnxiety - 0.4) * 0.7
      ))
    // Coach style suggestion (only if the user hasn't explicitly picked one in
    // onboarding — the Coach Style step sets `coachMode` directly, which we
    // respect here by only nudging on high-signal extremes).
    if profile.attachmentAnxiety > 0.65 {
      coachMode = .therapist
    } else if profile.confidence >= 8 {
      coachMode = .alphaMentor
    } else if profile.flirtingStyle.localizedCaseInsensitiveContains("playful") {
      coachMode = .wingman
    }
  }

  /// Strength-framed attachment label (never a clinical diagnosis). Used on the
  /// personalized plan as a starting point, not a verdict.
  static func attachmentLabel(anxiety: Double, avoidance: Double) -> String {
    switch (anxiety > 0.55, avoidance > 0.55) {
    case (false, false): return "Secure-leaning"
    case (true, false): return "Warm & invested"
    case (false, true): return "Independent & measured"
    case (true, true): return "Guarded but growing"
    }
  }

  /// Compact personalization summary injected into the AI coach system prompt
  /// (passed to the `coach` edge function). Keeps the model grounded in the
  /// user's goals, tone preference, and growth edges.
  /// TODO(backend): the `coach` edge function must read this `personalization`
  /// field and interpolate it into the system prompt once deployed.
  var coachPersonalizationSummary: String {
    let gentleness = profile.feedbackGentleness > 0.6 ? "gentle, encouraging" : "direct, candid"
    return [
      "Goal: \(profile.goal).",
      "Experience: \(profile.experience).",
      "Confidence: \(profile.confidence)/10.",
      "Flirting style: \(profile.flirtingStyle).",
      "Attachment lean: \(profile.attachmentLabel).",
      "Focus areas: \(profile.focusAreas.sorted().joined(separator: ", ")).",
      "Preferred feedback tone: \(gentleness).",
    ].joined(separator: " ")
  }

  /// Called when onboarding completes. Seeds the recommended starting track's
  /// first lecture as `current` (in addition to Track 1's first lecture, which
  /// always stays available) so the personalized plan's first lesson is real.
  func unlockRecommendedStart() {
    let track = recommendedStartTrack
    if let first = Curriculum.lectures(in: track.id).first(where: { !$0.isCapstone }),
      progress[first.id] == nil
    {
      progress[first.id] = LectureProgress()
    }
  }

  /// The free taster lecture surfaced right after the personalized plan. Prefer
  /// the recommended track's opener; fall back to the first overall lecture.
  var tasterLecture: Lecture? {
    Curriculum.lectures(in: recommendedStartTrack.id).first(where: { !$0.isCapstone })
      ?? Curriculum.lectures.first
  }

  // MARK: - Subscription

  func startTrial() {
    subscriptionStatus = .trial
    subscriptionPlan = .yearly
    trialStartedAt = .now
    trialEndsAt = Calendar.current.date(byAdding: .day, value: 3, to: .now)
  }

  func setPro(plan: SubscriptionPlan) {
    subscriptionStatus = .pro
    subscriptionPlan = plan
  }

  func recordCancelReason(_ reason: String) {
    cancelReason = reason
  }

  func markSaveOfferClaimed() {
    saveOfferClaimedAt = .now
  }

  // MARK: - Daily reset

  @discardableResult
  private func rollDailyResetIfNeeded() -> Bool {
    let cal = Calendar.current
    if !cal.isDateInToday(dailyResetAt) {
      dailyResetAt = cal.startOfDay(for: .now)
      dailyLiveSessionsUsed = 0
      sandboxUsedToday = false
      chargeMinutes = profile.dailyGoalMinutes
      return true
    }
    return false
  }

  // MARK: - Reset progress / delete account

  func resetProgress() {
    progress.removeAll()
    recentResults.removeAll()
    aura = 0
    streakDays = 0
    dailyLiveSessionsUsed = 0
    sandboxUsedToday = false
    Task { await bootstrap() }
  }

  func deleteAccount() {
    resetProgress()
    profile = PersonalizationProfile()
    hasCompletedOnboarding = false
    subscriptionStatus = .locked
    subscriptionPlan = .none
    trialStartedAt = nil
    trialEndsAt = nil
    cancelReason = nil
    saveOfferClaimedAt = nil
    streakFreezesRemaining = streakFreezeMonthlyAllowance
    lastStreakFreezeRefill = .distantPast
    SettingsStore.wipeAll()
    // TODO(backend): call Supabase /delete-account RPC to wipe server-side
    // profile, sessions, and progress once the auth/edge-function path lands.
  }

  // MARK: - Preview

  static var preview: AppState {
    let s = AppState()
    s.hasCompletedOnboarding = true
    s.aura = 72
    s.streakDays = 5
    s.profile.name = "Alex"
    s.profile.focusAreas = ["Opening", "Flow", "Calibration"]
    if let first = Curriculum.lectures.first {
      var p = LectureProgress()
      p.watched = true
      p.quizCorrect = 3
      p.practiced = true
      p.mastery = .silver
      s.progress[first.id] = p
    }
    if Curriculum.lectures.count > 1 {
      s.progress[Curriculum.lectures[1].id] = LectureProgress()
    }
    return s
  }
}
