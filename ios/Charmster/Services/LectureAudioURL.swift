import Foundation

/// SINGLE SOURCE OF TRUTH for pre-generated lecture-beat narration audio URLs.
///
/// Files live in the public Supabase Storage bucket `Avatars` under:
///   `Lectures/{coachStorageId}/{audioLectureId}/{beatFile}.mp3`
///
/// where:
///   - `coachStorageId` matches the coach folder used elsewhere (e.g. `dr_ray`
///     lives under `ray`), kept consistent with `CoachClipCatalog` /
///     `CoachPreviewLineURL`.
///   - `audioLectureId` is the per-lecture slug `t{track}-l{number}`, derived
///     from `Lecture.trackId` + `Lecture.number` (capstones use the same
///     number convention the curriculum assigns).
///   - `beatFile` is the per-beat filename, below.
///
/// The recall beat needs TWO clips played in order: the question, then the
/// reason ("why") revealed after answering. Every other beat is a single clip.
///
/// This is intentionally DATA-ONLY: to repoint or add audio, drop the MP3 in
/// the bucket at the path this builder produces — no narrator/view edits.
enum LectureAudioURL {

  private static var storageBase: String {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    return (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  private static let bucket = "Avatars"
  private static let root = "Lectures"

  /// Maps a `CoachPersona.id` to its Storage folder name (matches the other
  /// coach asset resolvers).
  static func storageId(forCoachId coachId: String) -> String {
    switch coachId {
    case "dr_ray": return "ray"
    default: return coachId
    }
  }

  /// Per-lecture audio slug, e.g. track 3 / number 4 -> `t3-l4`.
  static func audioLectureId(trackId: Int, number: Int) -> String {
    "t\(trackId)-l\(number)"
  }

  /// Which beat segment to fetch. The recall beat has two distinct files.
  enum Segment {
    case beat(LectureBeatKind)
    case recallQuestion
    case recallWhy

    /// Filename (without extension) inside the lecture's audio folder.
    var fileStem: String {
      switch self {
      case .beat(let kind):
        switch kind {
        case .hook: return "hook"
        case .coreInsight: return "core-insight"
        case .goodVsBad: return "good-vs-bad"
        case .recallCheck: return "recall-question"  // default single-clip mapping
        case .takeawayHandoff: return "takeaway"
        }
      case .recallQuestion: return "recall-question"
      case .recallWhy: return "recall-why"
      }
    }
  }

  /// Build the public URL for one lecture-beat audio segment. Returns `nil`
  /// only if URL encoding fails.
  static func url(coachId: String, trackId: Int, number: Int, segment: Segment) -> URL? {
    let coach = storageId(forCoachId: coachId)
    let lectureSlug = audioLectureId(trackId: trackId, number: number)
    let objectPath =
      "\(bucket)/\(root)/\(coach)/\(lectureSlug)/\(segment.fileStem).mp3"
    guard
      let encoded = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    else { return nil }
    return URL(string: "\(storageBase)/storage/v1/object/public/\(encoded)")
  }
}
