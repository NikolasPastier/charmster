import Foundation

// MARK: - JournalEntry
//
// A persisted history row written on every completed session (P6). It mirrors
// the data the feedback card already computes — this is NOT a new source of
// truth, just durable storage of `SessionResult` plus the session context and
// the coach's simulated "she'd feel" line.

struct JournalEntry: Identifiable, Codable, Hashable {
  let id: UUID
  let timestamp: Date

  // Context
  let lectureId: String?
  let lectureTitle: String?   // stored at write time; nil on pre-migration entries
  let skill: String
  let coachId: String
  let setting: String
  let tier: String  // DifficultyTier.rawValue
  let isSandbox: Bool

  // The 6 scored dimensions (+ comfort) and the session score.
  let responsiveness: Int
  let voice: Int
  let face: Int
  let body: Int
  let synchrony: Int
  let calibration: Int
  let comfort: Int
  let sessionScore: Int
  let auraAfter: Int

  /// The coach's simulated "she'd feel …" line (from the feedback engine).
  let feltLine: String

  // The six tracked dimensions, in a stable order, as (label, value).
  var dimensions: [(String, Int)] {
    [
      ("Responsiveness", responsiveness),
      ("Voice", voice),
      ("Face", face),
      ("Body", body),
      ("Synchrony", synchrony),
      ("Calibration", calibration),
    ]
  }

  static let dimensionKeys = [
    "Responsiveness", "Voice", "Face", "Body", "Synchrony", "Calibration",
  ]

  func value(forDimension key: String) -> Int {
    switch key {
    case "Responsiveness": return responsiveness
    case "Voice": return voice
    case "Face": return face
    case "Body": return body
    case "Synchrony": return synchrony
    case "Calibration": return calibration
    default: return 0
    }
  }
}

// MARK: - JournalStore
//
// UserDefaults-backed JSON store for the session-history rows + running
// per-dimension personal bests. Capped so it never grows unbounded.

enum JournalStore {
  private static let entriesKey = "charmster.journal.entries.v1"
  private static let bestsKey = "charmster.journal.bests.v1"
  private static let maxEntries = 200

  static func loadEntries() -> [JournalEntry] {
    guard let data = UserDefaults.standard.data(forKey: entriesKey) else { return [] }
    return (try? JSONDecoder().decode([JournalEntry].self, from: data)) ?? []
  }

  static func saveEntries(_ entries: [JournalEntry]) {
    let trimmed = Array(entries.suffix(maxEntries))
    guard let data = try? JSONEncoder().encode(trimmed) else { return }
    UserDefaults.standard.set(data, forKey: entriesKey)
  }

  static func loadBests() -> [String: Int] {
    (UserDefaults.standard.dictionary(forKey: bestsKey) as? [String: Int]) ?? [:]
  }

  static func saveBests(_ bests: [String: Int]) {
    UserDefaults.standard.set(bests, forKey: bestsKey)
  }

  static func wipe() {
    UserDefaults.standard.removeObject(forKey: entriesKey)
    UserDefaults.standard.removeObject(forKey: bestsKey)
  }
}

// MARK: - SessionLabels
//
// Single source of truth for the (primary, secondary?) label pair shown on every
// session row. Both ProfileView and JournalView call this so they can never drift.

struct SessionLabels {
  let primary: String
  let secondary: String?

  // From a persisted JournalEntry (Progress Journal list).
  static func from(_ entry: JournalEntry) -> SessionLabels {
    if entry.isSandbox {
      let coachName = CoachPersona.library.first(where: { $0.id == entry.coachId })?.humanName
        ?? entry.coachId
      return SessionLabels(primary: "Sandbox", secondary: "\(coachName) · \(entry.setting)")
    }
    // Prefer the stored title; fall back to Curriculum lookup for pre-migration rows.
    let title = entry.lectureTitle
      ?? Curriculum.lecture(id: entry.lectureId ?? "")?.title
      ?? entry.skill
    return SessionLabels(primary: title, secondary: entry.skill)
  }

  // From an in-memory SessionResult (Profile list).
  static func from(_ result: SessionResult) -> SessionLabels {
    if result.isSandbox {
      return SessionLabels(primary: "Sandbox", secondary: nil)
    }
    if let lecture = Curriculum.lecture(id: result.lectureId ?? "") {
      return SessionLabels(primary: lecture.title, secondary: lecture.skill)
    }
    return SessionLabels(primary: "Session", secondary: nil)
  }
}
