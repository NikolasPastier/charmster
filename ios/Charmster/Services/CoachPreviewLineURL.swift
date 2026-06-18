import Foundation

/// SINGLE SOURCE OF TRUTH for coach voice preview-line URLs.
///
/// Files live in the public Supabase Storage bucket `Avatars` under:
///   `Coaches/{coachId}/preview line/{coachId} preview line {n}.mp3`
///
/// Both the folder ("preview line") and filenames contain SPACES, so every path
/// segment is URL-encoded here (space -> %20). Never hand-build these URLs at a
/// call site — go through `url(coachId:index:)` so encoding lives in one place.
enum CoachPreviewLineURL {

  /// Number of preview lines per coach, always played 1 -> 2 -> 3.
  static let lineCount = 3

  private static var storageBase: String {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    return (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  /// Maps a `CoachPersona.id` to its Storage folder name. Identical for most
  /// coaches; `dr_ray` lives under `ray` in the bucket (matching CoachClipCatalog).
  static func storageId(forCoachId coachId: String) -> String {
    switch coachId {
    case "dr_ray": return "ray"
    default: return coachId
    }
  }

  /// Build the public URL for a coach's preview line. `index` is 1-based (1...3).
  /// Returns `nil` only if the index is out of range or encoding fails.
  static func url(coachId: String, index: Int) -> URL? {
    guard (1...lineCount).contains(index) else { return nil }
    let id = storageId(forCoachId: coachId)
    // Raw, human-readable object path with spaces — encoded below.
    let objectPath = "Avatars/Coaches/\(id)/preview line/\(id) preview line \(index).mp3"
    guard
      let encoded = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    else { return nil }
    return URL(string: "\(storageBase)/storage/v1/object/public/\(encoded)")
  }

  /// Ordered preview-line URLs [line1, line2, line3] for a coach. Skips any
  /// segment that fails to build (extremely unlikely) so order is preserved.
  static func lines(forCoachId coachId: String) -> [URL] {
    (1...lineCount).compactMap { url(coachId: coachId, index: $0) }
  }
}

extension CoachPersona {
  /// Ordered voice preview-line URLs, exactly [line1, line2, line3] in play order.
  var previewLines: [URL] { CoachPreviewLineURL.lines(forCoachId: id) }
}
