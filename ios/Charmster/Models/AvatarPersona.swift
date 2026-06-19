import Foundation

// MARK: - AvatarPersona (practice avatar "look")

/// A photoreal practice-avatar LOOK. This is the AI practice partner the user
/// rehearses with — NOT the human's own profile picture.
///
/// Data-driven by design: adding a new look later is a folder upload in the
/// `Avatars` Storage bucket + one row in `library` below. No view/director code
/// changes are needed.
///
/// Storage layout (confirmed in audit — capitalized top-level folder per look,
/// filenames contain SPACES, so the stored path is percent-encoded as-is and
/// NEVER lowercased or derived by naive transformation):
///   `{Look}/stills/{Look} neutral scene.jpeg`  ← the DISPLAYED photo (branded
///       scene background baked in). Used for the picker thumbnail AND every
///       avatar display.
///   `{Look}/stills/{Look}.jpeg`                ← plain cutout backup only,
///       not the displayed photo.
struct AvatarPersona: Identifiable, Hashable, Codable {
  enum Gender: String, Codable { case feminine, masculine, androgynous }

  let id: String
  let displayName: String
  let gender: Gender
  /// Short look description (skin tone / hair) — copy only, not used for asset
  /// resolution.
  let lookBlurb: String
  /// EXPLICIT object path inside the `Avatars` bucket for this look's displayed
  /// photo (the branded "neutral scene" still). Stored verbatim with its real
  /// casing and spaces — do not derive this by lowercasing the id.
  let thumbnailPath: String

  /// Default partner name prefilled when this look is selected (user-overridable).
  var defaultDisplayName: String { displayName }

  /// All practice looks. FEMALE-only catalog. Mia is the default selection.
  /// Each entry uses the "{Look} neutral scene.jpeg" file as its displayed photo.
  static let library: [AvatarPersona] = [
    .init(
      id: "mia", displayName: "Mia", gender: .feminine,
      lookBlurb: "Fair-medium, brunette",
      thumbnailPath: "Mia/stills/Mia neutral scene.jpeg"),
    .init(
      id: "ava", displayName: "Ava", gender: .feminine,
      lookBlurb: "Fair, blonde",
      thumbnailPath: "ava/stills/Ava neutral scene.jpeg"),
    .init(
      id: "sofia", displayName: "Sofia", gender: .feminine,
      lookBlurb: "Olive/tan, dark wavy",
      thumbnailPath: "Sofia/stills/Sofia neutral scene.jpeg"),
    .init(
      id: "mei", displayName: "Mei", gender: .feminine,
      lookBlurb: "Light-medium, black straight",
      thumbnailPath: "Mei/stills/Mei neutral scene.jpeg"),
    .init(
      id: "nia", displayName: "Nia", gender: .feminine,
      lookBlurb: "Deep skin, curly/coily",
      thumbnailPath: "Nia/stills/Nia neutral scene.jpeg"),
  ]

  static let `default` = AvatarPersona.library[0]

  /// Resolve a look from a stored look id. Unknown / removed ids (e.g. a legacy
  /// male look) migrate to the default look (Mia).
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
