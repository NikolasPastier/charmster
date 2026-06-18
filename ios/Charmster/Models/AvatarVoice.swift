import Foundation

// MARK: - AvatarVoice (practice partner's VOICE, named by vibe)

/// A selectable VOICE for the AI practice partner — DECOUPLED from the avatar
/// LOOK (any voice pairs with any look). Named by VIBE, never by an avatar's
/// name, so a user can pick "Mia" the look with the "Bright & bubbly" voice.
///
/// Data-driven by design, exactly like `AvatarPersona`: adding a voice later is
/// an MP3 upload to `Avatars/Voices/` + one row in `library` below. No view or
/// pipeline code changes are needed.
///
/// Storage layout (confirmed in audit — public `Avatars` bucket, `Voices`
/// folder; filenames contain SPACES and "&", so the EXACT path is stored per
/// entry and percent-encoded as-is — never lowercased or derived):
///   `Avatars/Voices/Mia Warm girlnextdoor.mp3`
///   `Avatars/Voices/Ava Bright & bubbly.mp3`
///   `Avatars/Voices/Sofia Warmlow & charming.mp3`
///   `Avatars/Voices/Mei Soft & calm.mp3`
///   `Avatars/Voices/Nia Poised & confident.mp3`
struct AvatarVoice: Identifiable, Hashable, Codable {
  /// Stable id persisted on the profile. Independent of the look id.
  let id: String
  /// User-facing VIBE label (never an avatar name).
  let displayName: String
  /// EXPLICIT object path inside the public `Avatars` bucket for this voice's
  /// preview clip. Stored verbatim with its real casing, spaces, and "&" — it
  /// is never derived by lowercasing the id.
  let previewPath: String
  /// Closest OpenAI Realtime voice for Route A (the live model voice).
  let realtimeVoice: String
  /// Optional ElevenLabs voice id for the later Route B swap (data-only).
  let elevenVoiceId: String?

  /// All selectable partner voices. "Warm girl-next-door" is the default.
  /// Adding a voice = upload mp3 + append one entry here.
  static let library: [AvatarVoice] = [
    .init(
      id: "warm_girl_next_door",
      displayName: "Warm girl-next-door",
      previewPath: "Voices/Mia Warm girlnextdoor.mp3",
      realtimeVoice: "shimmer",
      elevenVoiceId: nil),
    .init(
      id: "bright_bubbly",
      displayName: "Bright & bubbly",
      previewPath: "Voices/Ava Bright & bubbly.mp3",
      realtimeVoice: "coral",
      elevenVoiceId: nil),
    .init(
      id: "warm_low_charming",
      displayName: "Warm-low & charming",
      previewPath: "Voices/Sofia Warmlow & charming.mp3",
      realtimeVoice: "sage",
      elevenVoiceId: nil),
    .init(
      id: "soft_calm",
      displayName: "Soft & calm",
      previewPath: "Voices/Mei Soft & calm.mp3",
      realtimeVoice: "alloy",
      elevenVoiceId: nil),
    .init(
      id: "poised_confident",
      displayName: "Poised & confident",
      previewPath: "Voices/Nia Poised & confident.mp3",
      realtimeVoice: "ash",
      elevenVoiceId: nil),
  ]

  /// Default selection used when none is chosen / for migration.
  static let `default` = AvatarVoice.library[0]
  static let defaultId = AvatarVoice.default.id

  /// Resolve a voice from a stored id. Unknown / removed ids migrate to the
  /// default voice.
  static func resolve(from voiceId: String?) -> AvatarVoice {
    guard let id = voiceId, !id.isEmpty else { return .default }
    return library.first { $0.id == id } ?? .default
  }

  /// Public preview URL, built from the EXACT stored path and percent-encoded.
  /// We encode "&" explicitly to %26 (it is otherwise legal in a path component
  /// and would NOT be escaped by `.urlPathAllowed`), and spaces become %20.
  var previewURL: URL? { AvatarVoice.publicURL(objectPath: previewPath) }

  /// Same public `Avatars` bucket + base as the stills resolver, but with a
  /// stricter allowed set so "&" is percent-encoded.
  static func publicURL(objectPath: String) -> URL? {
    let path = objectPath.trimmingCharacters(in: .whitespaces)
    guard !path.isEmpty else { return nil }
    // Start from urlPathAllowed, then REMOVE "&" so it gets escaped to %26.
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "&")
    guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed) else {
      return nil
    }
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    let base = (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return URL(string: "\(base)/storage/v1/object/public/Avatars/\(encoded)")
  }
}
