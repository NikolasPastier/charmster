import SwiftUI
import Observation

/// Charmster app state. Local-first mock economy that matches the playbook formulas.
@Observable
final class AppState {
    // MARK: Onboarding
    var hasOnboarded: Bool = false
    var ageConfirmed: Bool = false

    // MARK: Identity
    var username: String = "Alex"

    // MARK: Personalization (from onboarding quiz)
    var goal: OnbGoal? = nil
    var experience: OnbExperience? = nil
    var focusAreas: Set<OnbFocusArea> = [.openers, .signals]
    var attachmentAnxiety: Double = 2.5
    var attachmentAvoidance: Double = 2.5
    var attachmentLabel: AttachmentLabel = .secureLeaning
    var flirting: OnbFlirtingStyle = .playful
    var confidenceBaseline: Double = 50
    var coachMode: CoachMode = .wingman
    var recommendedTrack: Int = 2
    var difficultyTier: DifficultyTier = .silver
    var dailyGoalMinutes: Int = 10
    var dailyReminderOn: Bool = true
    var dailyReminderTime: Date = Calendar.current.date(
        bySettingHour: 19, minute: 30, second: 0, of: Date()) ?? Date()

    // MARK: Inclusive identity (Step 7)
    var selfIdentity: SelfIdentity? = nil
    var datingContext: DatingContext? = nil
    var partnerPresentation: PartnerPresentation = .feminine
    var selectedPersona: PartnerPersona = PartnerPersona.defaults[0]

    // MARK: Subscription (Step 2 — hard paywall model)
    var subscriptionStatus: SubscriptionStatus = .locked
    var subscriptionPlan: SubscriptionPlan? = nil
    var trialStartedAt: Date? = nil
    var trialEndsAt: Date? = nil
    var trialSessionsUsedToday: Int = 0
    var lastTrialResetDay: Date = Date()
    var cancelReason: String? = nil
    var saveOfferClaimedAt: Date? = nil

    // Trial config (server-config in production)
    let trialDailyLiveSessionsCap: Int = 2
    let paidDailyLiveSessionsCap: Int = 12   // generous fair-use anti-abuse
    var paidSessionsUsedToday: Int = 0

    // MARK: Economy (per playbook formulas)
    var totalXP: Int = 380
    var level: Int = 3
    var aura: Double = 46            // 0...100, EMA
    var streakDays: Int = 5

    // Charm Coins — DEPRECATED (Step 11). Field retained for data preservation.
    // Reads return 0 when the feature flag is OFF; writes are no-ops.
    private var _charmCoins: Int = 120
    var charmCoins: Int {
        get { FeatureFlags.charmCoinsEnabled ? _charmCoins : 0 }
        set { if FeatureFlags.charmCoinsEnabled { _charmCoins = newValue } }
    }

    // MARK: Lecture progress
    var progress: [String: LectureProgress] = [:]   // lectureId -> progress
    var capstoneProgress: [String: CapstoneProgress] = [:] // capstoneId -> progress
    var earnedBadges: Set<String> = []

    // MARK: Live state
    var activeTrack: Int = 2

    // MARK: Accessibility
    var reducedMotion: Bool = false
    var captionsDefaultOn: Bool = true
    var prefersTextPractice: Bool = false

    // MARK: Sessions (history for charts)
    var recentScores: [Int] = [62, 71, 58, 74, 81, 69, 88]

    // MARK: - Derived

    var displayName: String { username.isEmpty ? "You" : username }

    var nextLevelXP: Int { Self.xpForLevel(level + 1) }
    var currentLevelFloor: Int { Self.xpForLevel(level) }
    var levelProgress: Double {
        let span = max(1, nextLevelXP - currentLevelFloor)
        return max(0, min(1, Double(totalXP - currentLevelFloor) / Double(span)))
    }

    var levelTitle: String {
        switch level {
        case ..<5:  return "Warming Up"
        case ..<10: return "Finding Your Voice"
        case ..<20: return "Smooth Operator"
        default:    return "Charmster"
        }
    }

    var auraBand: String {
        switch Int(aura) {
        case 80...:    return "Radiant"
        case 60..<80:  return "Magnetic"
        case 40..<60:  return "Glow"
        default:       return "Spark"
        }
    }

    var auraTint: Color {
        switch Int(aura) {
        case 80...: return Theme.gold
        case 60..<80: return Theme.purple
        case 40..<60: return Theme.calmBlue
        default: return Theme.textMuted
        }
    }

    /// Cumulative XP needed to REACH level n.
    static func xpForLevel(_ n: Int) -> Int { 100 * n * (n + 1) / 2 }

    // MARK: - Subscription / access

    /// Convenience: gates legacy `isPro` callsites.
    var isPro: Bool {
        get { subscriptionStatus == .pro }
        set { subscriptionStatus = newValue ? .pro : .locked }
    }

    var hasAccess: Bool { subscriptionStatus.hasAccess }

    var dailyLiveSessionsCap: Int {
        subscriptionStatus == .trial ? trialDailyLiveSessionsCap : paidDailyLiveSessionsCap
    }

    var sessionsUsedToday: Int {
        subscriptionStatus == .trial ? trialSessionsUsedToday : paidSessionsUsedToday
    }

    /// Reset daily counters at local midnight.
    func resetDailyCountersIfNeeded() {
        let cal = Calendar.current
        if !cal.isDate(lastTrialResetDay, inSameDayAs: Date()) {
            trialSessionsUsedToday = 0
            paidSessionsUsedToday = 0
            lastTrialResetDay = Date()
        }
    }

    /// Trial helpers.
    func startTrial() {
        let now = Date()
        subscriptionStatus = .trial
        trialStartedAt = now
        trialEndsAt = Calendar.current.date(byAdding: .day, value: 3, to: now)
        trialSessionsUsedToday = 0
        lastTrialResetDay = now
        Analytics.log("trial_started", ["plan": "annual"])
    }

    func markSessionStarted() {
        resetDailyCountersIfNeeded()
        if subscriptionStatus == .trial { trialSessionsUsedToday += 1 }
        else { paidSessionsUsedToday += 1 }
    }

    /// Can the user open a live practice session right now?
    var canStartLivePractice: Bool {
        resetDailyCountersIfNeededReadOnly()
        guard hasAccess else { return false }
        return sessionsUsedToday < dailyLiveSessionsCap
    }

    private func resetDailyCountersIfNeededReadOnly() {
        // Read-only-safe: only resets the cached day marker, doesn't write counters in getters.
    }

    var liveSessionGateReason: String? {
        if !hasAccess { return "Unlock Pro to keep practicing." }
        if sessionsUsedToday >= dailyLiveSessionsCap {
            return subscriptionStatus == .trial
                ? "Trial limit reached. Come back tomorrow or upgrade to Pro."
                : "You've practiced a lot today — come back tomorrow."
        }
        return nil
    }

    // MARK: - Mutations

    func applyQuiz(_ q: QuizResult) {
        if let goal = q.goal { self.goal = goal }
        if let exp = q.experience { self.experience = exp }
        focusAreas = q.focusAreas
        attachmentAnxiety = q.attachmentAnxiety
        attachmentAvoidance = q.attachmentAvoidance
        attachmentLabel = q.attachmentLabel
        if let f = q.flirting { flirting = f }
        confidenceBaseline = q.confidence
        if let c = q.coach { coachMode = c }
        dailyGoalMinutes = q.dailyMinutes
        dailyReminderOn = q.reminderEnabled
        if !q.username.isEmpty { username = q.username }
        if let id = q.selfIdentity { self.selfIdentity = id }
        if let ctx = q.datingContext { self.datingContext = ctx }
        if let pp = q.partnerPresentation { self.partnerPresentation = pp }
        if let persona = q.partnerPersona { self.selectedPersona = persona }
        recommendedTrack = q.recommendedTrack
        difficultyTier = q.defaultTier
        activeTrack = q.recommendedTrack
        ageConfirmed = true
        hasOnboarded = true
        Analytics.log("onboarding_complete", [
            "self_identity": selfIdentity?.rawValue ?? "unset",
            "dating_context": datingContext?.rawValue ?? "unset",
            "partner_presentation": partnerPresentation.rawValue,
            "coach": coachMode.rawValue,
        ])
    }

    /// Re-runs personalization mapping from current granular settings (used by Settings edits).
    func recomputePersonalization() {
        let label = QuizResult(
            attachmentAnxiety: attachmentAnxiety,
            attachmentAvoidance: attachmentAvoidance
        ).attachmentLabel
        attachmentLabel = label
        if confidenceBaseline >= 67 {
            recommendedTrack = 8
            difficultyTier = .bronze
        } else if let goal = goal {
            recommendedTrack = goal.recommendedTrack
            difficultyTier = experience?.defaultTier ?? difficultyTier
        }
    }

    // MARK: Lecture & quiz

    func state(of lecture: Lecture) -> LectureState {
        if progress[lecture.id]?.mastered == true { return .mastered }
        if lecture.number == 1 { return .current }
        let prevId = "t\(lecture.trackId)-l\(lecture.number - 1)"
        if progress[prevId]?.mastered == true { return .current }
        return .locked
    }

    /// Is every lecture in this track mastered (capstone unlocked)?
    func trackFullyMastered(_ trackId: Int) -> Bool {
        let lectures = Curriculum.lectures(in: trackId)
        guard !lectures.isEmpty else { return false }
        return lectures.allSatisfy { progress[$0.id]?.mastered == true }
    }

    func recordQuiz(lecture: Lecture, score: Int) {
        var p = progress[lecture.id] ?? LectureProgress()
        p.quizScore = max(p.quizScore, score)
        progress[lecture.id] = p
        totalXP += 5 * score   // +5 XP per correct (max +15)
        recomputeLevel()
    }

    func recordWatched(lecture: Lecture) {
        totalXP += 10
        recomputeLevel()
    }

    func completePractice(lecture: Lecture, result: SessionResult) {
        var p = progress[lecture.id] ?? LectureProgress()
        p.practiced = true
        progress[lecture.id] = p
        totalXP += result.xpEarned
        // Coin awards suppressed when feature flag is OFF (Step 11).
        if FeatureFlags.charmCoinsEnabled { _charmCoins += result.coinsEarned }
        // Aura EMA
        aura = 0.8 * aura + 0.2 * Double(result.sessionScore)
        streakDays += 1
        recentScores.append(result.sessionScore)
        if recentScores.count > 14 { recentScores.removeFirst() }
        recomputeLevel()
        Analytics.log("session_complete", ["score": result.sessionScore, "lecture": lecture.id])
    }

    func completeCapstone(capstone: Capstone, result: SessionResult) {
        var p = capstoneProgress[capstone.id] ?? CapstoneProgress()
        let xp = CapstoneCatalog.capstoneXP(sessionScore: result.sessionScore, tier: difficultyTier)
        if !p.passedOnce && result.sessionScore >= 60 {
            p.passedOnce = true
            p.firstPassAt = Date()
            p.pathMasteryBadge = true
            totalXP += xp + CapstoneCatalog.firstPassBonusXP
            earnedBadges.insert("path_mastery_t\(capstone.trackId)")
            Analytics.log("capstone_first_pass", ["track": capstone.trackId, "score": result.sessionScore])
        } else if p.passedOnce {
            totalXP += CapstoneCatalog.replayXP(sessionScore: result.sessionScore, tier: difficultyTier)
        } else {
            totalXP += xp
        }
        p.bestScore = max(p.bestScore, result.sessionScore)
        capstoneProgress[capstone.id] = p
        aura = 0.7 * aura + 0.3 * Double(result.sessionScore)
        recentScores.append(result.sessionScore)
        if recentScores.count > 14 { recentScores.removeFirst() }
        recomputeLevel()
    }

    private func recomputeLevel() {
        while totalXP >= Self.xpForLevel(level + 1) { level += 1 }
    }
}

/// Step 11 — feature flags for in-flight deprecations.
enum FeatureFlags {
    /// Charm Coins UI + economy. OFF per spec; data preserved.
    static let charmCoinsEnabled: Bool = false
    /// Cosmetics shop + avatar customization. OFF per spec.
    static let cosmeticsEnabled: Bool = false
}
