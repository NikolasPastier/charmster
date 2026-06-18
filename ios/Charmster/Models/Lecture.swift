import Foundation

// MARK: - Access tier + format

enum LectureAccess: String, Codable, Hashable {
  case free
  case taster
  case pro
}

enum LectureFormat: String, Codable, Hashable {
  case video
  case text
  case quiz
  case assessment
}

// MARK: - Lecture

struct Lecture: Identifiable, Hashable, Codable {
  let id: String  // "<track>.<number>" e.g. "3.4"; capstones use "<track>.capstone"
  let trackId: Int
  let number: Int  // 1-based within track; capstone uses (lectures.count + 1)
  let title: String
  let scenario: String
  let minutes: Int
  let skill: String
  let isCapstone: Bool
  let access: LectureAccess
  let format: LectureFormat

  var displayNumber: String { isCapstone ? "\(trackId).★" : "\(trackId).\(number)" }
}

// MARK: - Track

struct Track: Identifiable, Hashable, Codable {
  let id: Int
  let slug: String
  let title: String
  let subtitle: String
  let coreQuestion: String
  let emoji: String
  let symbol: String
  let order: Int
  let accessDefault: LectureAccess
  let lectureCount: Int
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
  let lectureId: String?  // nil for sandbox
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
  let auraEarned: Int
  let streakKept: Bool
  let coinsEarned: Int  // kept in model, hidden from UI
  let durationSeconds: Int
  let safetyCapApplied: Bool
  let createdAt: Date
}
