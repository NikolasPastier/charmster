import Foundation

/// SINGLE SOURCE OF TRUTH for pre-generated lecture-beat narration audio URLs.
///
/// Files live in the public Supabase Storage bucket `lecture-audio` under:
///   `{lectureId}/{coachId}/{beatId}.mp3`     e.g.  `t1-l1/leo/hook.mp3`
///
/// where:
///   - `lectureId` is the per-lecture slug `t{track}-l{number}`, derived from
///     `Lecture.trackId` + `Lecture.number` (e.g. `t1-l1`, `t10-l10`).
///   - `coachId` is `CoachPersona.id` AS-IS: `theo`, `dr_ray`, `cole`, `noah`,
///     `leo`. Do NOT remap `dr_ray -> ray` here — that remap is only for the
///     VIDEO clip resolvers, not audio.
///   - `beatId` is the per-beat filename: `hook`, `coreInsight`, `goodVsBad`,
///     `recallQuestion`, `recallWhy`, `takeawayHandoff`.
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
    var beatId: String {
      switch self {
      case .beat(let kind):
        switch kind {
        case .hook: return "hook"
        case .coreInsight: return "coreInsight"
        case .goodVsBad: return "goodVsBad"
        case .recallCheck: return "recallQuestion"  // default single-clip mapping
        case .takeawayHandoff: return "takeawayHandoff"
        }
      case .recallQuestion: return "recallQuestion"
      case .recallWhy: return "recallWhy"
      }
    }
  }

  /// CONFIRMED CANONICAL BUILDER.
  /// `lecture-audio/{lectureId}/{coachId}/{beatId}.mp3`
  static func lectureAudioURL(lectureId: String, coachId: String, beatId: String) -> URL? {
    let base = storageBase
    let path = "lecture-audio/\(lectureId)/\(coachId)/\(beatId).mp3"
    guard let enc = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
      return nil
    }
    return URL(string: "\(base)/storage/v1/object/public/\(enc)")
  }

  /// Convenience overload used by the narrator: passes `CoachPersona.id`
  /// directly (no clip-storage remap) and derives the lecture slug.
  static func url(coachId: String, trackId: Int, number: Int, segment: Segment) -> URL? {
    let lectureId = audioLectureId(trackId: trackId, number: number)
    return lectureAudioURL(lectureId: lectureId, coachId: coachId, beatId: segment.beatId)
  }
}
