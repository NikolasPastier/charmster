import Foundation

// MARK: - CoachAvatarState
//
// Lean coach playback state set (spec P2). Looping base: idle, talking,
// thinking. One-shot reactions: emphasize, affirm, laugh — they play once and
// return to the previous looping base.
enum CoachAvatarState: String, Codable, CaseIterable {
  case idle
  case talking
  case thinking
  case emphasize
  case affirm
  case laugh

  var isLooping: Bool {
    switch self {
    case .idle, .talking, .thinking: return true
    case .emphasize, .affirm, .laugh: return false
    }
  }
}
