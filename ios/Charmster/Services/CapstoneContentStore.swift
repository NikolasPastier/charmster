import Foundation

struct CapstoneContent: Decodable {

  struct Stage: Decodable {
    let key: String
    let label: String
    let goal: String
    let situation: String
    let successCue: String
    let failCue: String
  }

  let id: String
  let track: Int
  let title: String
  let type: String
  let premise: String
  let persona: String
  let setting: String
  let scoringEmphasis: [String]
  let passThreshold: Int
  let coachIntro: String
  let coachRecap: String
  let stages: [Stage]
}

private struct CapstoneManifest: Decodable {
  let capstones: [CapstoneContent]
}

/// Loads `capstone_content.json` from the bundle once and provides O(1) lookup
/// by track id (matches `Lecture.trackId`). Thread-safe after init.
@MainActor
final class CapstoneContentStore {

  static let shared = CapstoneContentStore()

  private let byTrack: [Int: CapstoneContent]

  init() {
    guard
      let url = Bundle.main.url(forResource: "capstone_content", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let manifest = try? JSONDecoder().decode(CapstoneManifest.self, from: data)
    else {
      byTrack = [:]
      return
    }
    var map: [Int: CapstoneContent] = [:]
    for cap in manifest.capstones { map[cap.track] = cap }
    byTrack = map
  }

  func content(for lecture: Lecture) -> CapstoneContent? {
    guard lecture.isCapstone else { return nil }
    return byTrack[lecture.trackId]
  }
}
