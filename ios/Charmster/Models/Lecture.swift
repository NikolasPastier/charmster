import Foundation

// MARK: - Lecture

struct Lecture: Identifiable, Hashable, Codable {
    let id: String
    let trackId: Int
    let number: Int          // 1-based within track
    let title: String
    let scenario: String
    let minutes: Int
    let skill: String
    let isCapstone: Bool

    var displayNumber: String { "\(trackId).\(number)" }
}

// MARK: - Track

struct Track: Identifiable, Hashable, Codable {
    let id: Int
    let title: String
    let subtitle: String
    let symbol: String

    static let library: [Track] = [
        .init(id: 0, title: "Beginner",     subtitle: "Open, hold, exit",         symbol: "leaf.fill"),
        .init(id: 1, title: "Conversation", subtitle: "Flow and callbacks",       symbol: "bubble.left.and.bubble.right.fill"),
        .init(id: 2, title: "Confidence",   subtitle: "Frame and presence",       symbol: "flame.fill"),
        .init(id: 3, title: "Mastery",      subtitle: "Reading the room",         symbol: "sparkles")
    ]
}

// MARK: - Progress

struct LectureProgress: Codable, Hashable {
    var watched: Bool = false
    var quizCorrect: Int = 0
    var practiced: Bool = false
    var mastery: MasteryTier = .none
    var lastPracticedAt: Date?
    // SM-2 spaced repetition fields
    var srsEase: Double = 2.5
    var srsIntervalDays: Int = 0
    var srsRepetitions: Int = 0
    var dueAt: Date?

    var isMastered: Bool { mastery != .none && quizCorrect >= 2 && practiced }
}

// MARK: - Session result

struct SessionResult: Identifiable, Hashable, Codable {
    let id: UUID
    let lectureId: String?       // nil for sandbox
    let isCapstone: Bool
    let isSandbox: Bool

    // Scored dimensions (0-100). Real signals come from SessionScorer.
    let responsiveness: Int
    let voice: Int
    let face: Int
    let body: Int
    let synchrony: Int
    let calibration: Int
    let comfort: Int

    let sessionScore: Int
    let xpEarned: Int
    let auraEarned: Int
    let streakKept: Bool
    let coinsEarned: Int          // kept in model, hidden from UI
    let durationSeconds: Int
    let safetyCapApplied: Bool
    let createdAt: Date
}
