import Foundation

// MARK: - Coach Nudge (UX4)
//
// A single, bite-size, in-the-moment coaching cue shown at the bottom of the
// live practice screen AFTER the user finishes a turn. It never interrupts the
// conversation: it's an overlay above the input/controls, auto-hides for
// praise, and is fully skippable.
//
// Nudges are DERIVED on-device from (1) the user's latest utterance and
// (2) how the practice avatar is currently feeling. No new network call is
// introduced — generation is deterministic and fails silently.

/// What kind of cue this is. Drives tone, icon, and anti-spam rules.
enum NudgeType: String, Codable {
  /// Short, rewarding "that landed" beat.
  case praise
  /// One concrete, actionable change (only ONE per nudge).
  case improvement
  /// Maps the avatar's current feeling → a suggested adjustment.
  case calibration

  var icon: String {
    switch self {
    case .praise: return "checkmark.seal.fill"
    case .improvement: return "arrow.up.forward.circle.fill"
    case .calibration: return "dial.medium.fill"
    }
  }
}

/// How aggressively the coach nudges. User-controlled in Settings.
enum NudgeLevel: String, Codable, CaseIterable, Identifiable {
  case off
  case minimal
  case coaching

  var id: String { rawValue }

  var title: String {
    switch self {
    case .off: return "Off"
    case .minimal: return "Minimal"
    case .coaching: return "Coaching"
    }
  }

  var blurb: String {
    switch self {
    case .off: return "No live cues during practice."
    case .minimal: return "Occasional praise only — stays out of the way."
    case .coaching: return "Praise plus one concrete tweak when it helps."
    }
  }

  /// Minimum user turns between two shown nudges at this level.
  var minTurnGap: Int {
    switch self {
    case .off: return .max
    case .minimal: return 3
    case .coaching: return 2
    }
  }

  /// Confidence floor below which we show nothing.
  var confidenceFloor: Double {
    switch self {
    case .off: return 1.1  // never passes
    case .minimal: return 0.62
    case .coaching: return 0.5
    }
  }

  /// Minimal hides improvement/calibration — it's praise-only.
  var allowsCriticalNudges: Bool { self == .coaching }
}

/// One generated cue. Value type — cheap to create, compare, and discard.
struct Nudge: Identifiable, Equatable {
  let id: UUID
  let type: NudgeType
  /// One sentence max, in the coach's voice. Truncated gracefully in the UI.
  let text: String
  /// Optional concrete rewrite the user can reveal via "Try this".
  let suggestionRewrite: String?
  /// One-line rationale revealed via "Why".
  let rationale: String?
  /// 0..1 — generation confidence; below the level floor we drop it.
  let confidence: Double
  /// The user turn this nudge was generated for (for rate-limiting).
  let messageTurnIndex: Int
  let coachPersonaId: String
  let createdAt: Date

  init(
    id: UUID = UUID(),
    type: NudgeType,
    text: String,
    suggestionRewrite: String? = nil,
    rationale: String? = nil,
    confidence: Double,
    messageTurnIndex: Int,
    coachPersonaId: String,
    createdAt: Date = .now
  ) {
    self.id = id
    self.type = type
    self.text = text
    self.suggestionRewrite = suggestionRewrite
    self.rationale = rationale
    self.confidence = confidence
    self.messageTurnIndex = messageTurnIndex
    self.coachPersonaId = coachPersonaId
    self.createdAt = createdAt
  }

  /// Praise auto-hides; improvement/calibration linger a touch longer so the
  /// user can read and optionally expand them.
  var autoHideSeconds: Double? {
    switch type {
    case .praise: return 5
    case .improvement, .calibration: return 8
    }
  }
}
