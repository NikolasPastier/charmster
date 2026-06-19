import Foundation

/// Per-lecture authored content. When a lecture has an entry here, the player
/// uses it instead of the skill-based templates in LectureStoryBuilder. Lectures
/// WITHOUT an entry fall back to the skill template and log a warning so missing
/// content is visible rather than silently masked.
struct PerLectureContent: Decodable {

  struct GoodVsBad: Decodable {
    let works: String
    let avoid: String
    let leansIn: String?
    let checksOut: String?
  }

  struct RecallContent: Decodable {
    let question: String
    let options: [String]
    let answerIndex: Int
    let explanation: String
  }

  let id: String
  let objectives: [String]?
  let goodVsBad: GoodVsBad?
  let recall: RecallContent?
}

private struct PerLectureManifest: Decodable {
  let lectures: [PerLectureContent]
}

/// Loads `per_lecture_content.json` from the bundle once and provides O(1) lookup
/// by lecture id. Thread-safe after init (dictionary is read-only at runtime).
@MainActor
final class PerLectureContentStore {

  static let shared = PerLectureContentStore()

  private let byId: [String: PerLectureContent]

  init() {
    guard
      let url = Bundle.main.url(forResource: "per_lecture_content", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let manifest = try? JSONDecoder().decode(PerLectureManifest.self, from: data)
    else {
      byId = [:]
      return
    }
    var map: [String: PerLectureContent] = [:]
    for lc in manifest.lectures { map[lc.id] = lc }
    byId = map
  }

  func content(for lectureId: String) -> PerLectureContent? {
    byId[lectureId]
  }

  /// All lecture IDs that have authored per-lecture content.
  var authoredIds: Set<String> { Set(byId.keys) }
}
