import Foundation

// MARK: - AvatarPersona

/// Photoreal video-clip avatar persona. Two ship at launch: Mia + Matteo.
/// Additional personas are a data-only change (extend `AvatarPersona.library`
/// and add manifest rows in `AvatarClipCatalog`).
struct AvatarPersona: Identifiable, Hashable, Codable {
  enum Gender: String, Codable { case feminine, masculine, androgynous }

  let id: String
  let displayName: String
  let gender: Gender
  /// Folder name inside the `avatar-clips` Supabase Storage bucket.
  let bucketFolder: String

  static let library: [AvatarPersona] = [
    .init(id: "mia", displayName: "Mia", gender: .feminine, bucketFolder: "mia"),
    .init(id: "mateo", displayName: "Matteo", gender: .masculine, bucketFolder: "matteo"),
  ]

  static let `default` = AvatarPersona.library[0]

  static func resolve(from personaId: String?) -> AvatarPersona {
    guard let id = personaId?.lowercased() else { return .default }
    return library.first { $0.id == id }
      ?? library.first { id.contains($0.id) }
      ?? .default
  }
}

// MARK: - AvatarState

/// Avatar playback states. `idle`/`listening`/`talking`/`thinking` are looping
/// base states; the rest are one-shot reactions that return to the previous
/// looping base state when finished.
enum AvatarState: String, Codable, CaseIterable {
  case idle
  case listening
  case talking
  case thinking
  case smile
  case laugh
  case flirty
  case surprised
  case cool
  case reassure

  var isLooping: Bool {
    switch self {
    case .idle, .listening, .talking, .thinking: return true
    default: return false
    }
  }

  /// Tag emitted by the Realtime model's `set_mood` tool. Mapped 1:1.
  static func fromMoodTag(_ tag: String) -> AvatarState? {
    switch tag.lowercased() {
    case "neutral": return .idle
    case "listening": return .listening
    case "talking": return .talking
    case "thinking": return .thinking
    case "smile": return .smile
    case "laugh": return .laugh
    case "flirty": return .flirty
    case "surprised": return .surprised
    case "cool": return .cool
    case "reassure": return .reassure
    default: return nil
    }
  }
}
