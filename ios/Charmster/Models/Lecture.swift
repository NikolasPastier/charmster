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

// MARK: - Opening turn

/// Who speaks first when the live session connects.
/// `.user` (default) preserves the existing cold-start behaviour.
/// `.avatar` fires a `response.create` on `session.created` so she approaches first.
enum OpeningTurn: String, Codable, Hashable {
  case user
  case avatar
}

// MARK: - Scoring profile

/// Per-lecture dimension weights used by SessionScorer.
/// All values are relative — SessionScorer renormalises over the active channels.
/// Lectures that omit this in the curriculum JSON use `.balanced` (all 1.0).
struct ScoringProfile: Codable, Hashable {
  var voice: Double
  var face: Double
  var body: Double
  var synchrony: Double
  var responsiveness: Double
  var calibration: Double

  static let balanced = ScoringProfile(
    voice: 1, face: 1, body: 1,
    synchrony: 1, responsiveness: 1, calibration: 1)
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
  let scoringProfile: ScoringProfile?
  let openingTurn: OpeningTurn

  init(
    id: String, trackId: Int, number: Int, title: String,
    scenario: String, minutes: Int, skill: String,
    isCapstone: Bool, access: LectureAccess, format: LectureFormat,
    scoringProfile: ScoringProfile? = nil,
    openingTurn: OpeningTurn = .user
  ) {
    self.id = id; self.trackId = trackId; self.number = number
    self.title = title; self.scenario = scenario; self.minutes = minutes
    self.skill = skill; self.isCapstone = isCapstone
    self.access = access; self.format = format
    self.scoringProfile = scoringProfile
    self.openingTurn = openingTurn
  }

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

// MARK: - ProgressStore
//
// UserDefaults-backed persistence for the per-lecture progress dictionary.
// Mirrors the JournalStore pattern so mastery, quiz state, and SRS schedules
// survive app restarts (previously all in-memory only).

enum ProgressStore {
  private static let key = "charmster.progress.v1"

  static func save(_ progress: [String: LectureProgress]) {
    guard let data = try? JSONEncoder().encode(progress) else { return }
    UserDefaults.standard.set(data, forKey: key)
  }

  static func load() -> [String: LectureProgress] {
    guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
    return (try? JSONDecoder().decode([String: LectureProgress].self, from: data)) ?? [:]
  }

  static func wipe() {
    UserDefaults.standard.removeObject(forKey: key)
  }
}

// MARK: - Session result

struct SessionResult: Identifiable, Hashable, Codable {
  let id: UUID
  let lectureId: String?  // nil for sandbox
  let isCapstone: Bool
  let isSandbox: Bool

  // On-device scored dimensions (0-100).
  // Dimensions dropped via channel-dropping are stored as 0.
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

  // Channel metadata (nil = old stored result, treat as camera used).
  let cameraUsed: Bool?

  // Feel-layer dims from the transcript judge (nil if judge unavailable or old result).
  let interest: Int?
  let spark: Int?
  let respect: Int?

  // Narrative feedback from the transcript judge.
  let reactionLine: String?
  let strengths: [String]?
  let fixes: [String]?

  init(
    id: UUID, lectureId: String?, isCapstone: Bool, isSandbox: Bool,
    responsiveness: Int, voice: Int, face: Int, body: Int,
    synchrony: Int, calibration: Int, comfort: Int,
    sessionScore: Int, auraEarned: Int, streakKept: Bool,
    coinsEarned: Int, durationSeconds: Int, safetyCapApplied: Bool,
    createdAt: Date,
    cameraUsed: Bool? = true,
    interest: Int? = nil, spark: Int? = nil, respect: Int? = nil,
    reactionLine: String? = nil, strengths: [String]? = nil, fixes: [String]? = nil
  ) {
    self.id = id; self.lectureId = lectureId
    self.isCapstone = isCapstone; self.isSandbox = isSandbox
    self.responsiveness = responsiveness; self.voice = voice
    self.face = face; self.body = body; self.synchrony = synchrony
    self.calibration = calibration; self.comfort = comfort
    self.sessionScore = sessionScore; self.auraEarned = auraEarned
    self.streakKept = streakKept; self.coinsEarned = coinsEarned
    self.durationSeconds = durationSeconds; self.safetyCapApplied = safetyCapApplied
    self.createdAt = createdAt
    self.cameraUsed = cameraUsed
    self.interest = interest; self.spark = spark; self.respect = respect
    self.reactionLine = reactionLine; self.strengths = strengths; self.fixes = fixes
  }
}
