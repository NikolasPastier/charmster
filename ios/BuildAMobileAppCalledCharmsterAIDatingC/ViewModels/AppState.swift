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

    // MARK: Economy (per playbook formulas)
    var totalXP: Int = 380
    var level: Int = 3
    var aura: Double = 46            // 0...100, EMA
    var charmCoins: Int = 120
    var streakDays: Int = 5

    // MARK: Charge meter (cost gate for live practice)
    var chargeMinutes: Int = 6       // free tier ~1 short session/day
    let chargeCap: Int = 6
    var lastChargeRefill: Date = Date()

    // MARK: Lecture progress
    var progress: [String: LectureProgress] = [:]   // lectureId -> progress

    // MARK: Live state
    var isPro: Bool = false
    var activeTrack: Int = 2

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
        recommendedTrack = q.recommendedTrack
        difficultyTier = q.defaultTier
        activeTrack = q.recommendedTrack
        ageConfirmed = true
        hasOnboarded = true
    }

    /// Re-runs personalization mapping from current granular settings (used by Settings edits).
    func recomputePersonalization() {
        let label = QuizResult(
            attachmentAnxiety: attachmentAnxiety,
            attachmentAvoidance: attachmentAvoidance
        ).attachmentLabel
        attachmentLabel = label
        // High confidence → Track 8 + bronze
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
        // Sequential within a track: lecture N unlocks when N-1 is mastered.
        if lecture.number == 1 { return .current }
        let prevId = "t\(lecture.trackId)-l\(lecture.number - 1)"
        if progress[prevId]?.mastered == true { return .current }
        return .locked
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
        charmCoins += result.coinsEarned
        // Aura EMA
        aura = 0.8 * aura + 0.2 * Double(result.sessionScore)
        // Streak
        streakDays += 1
        recentScores.append(result.sessionScore)
        if recentScores.count > 14 { recentScores.removeFirst() }
        // Charge: practice minutes consume (mock 3 min)
        chargeMinutes = max(0, chargeMinutes - 3)
        recomputeLevel()
    }

    private func recomputeLevel() {
        while totalXP >= Self.xpForLevel(level + 1) { level += 1 }
    }

    // MARK: Charge gate

    var canStartLivePractice: Bool { isPro || chargeMinutes >= 3 }
}
