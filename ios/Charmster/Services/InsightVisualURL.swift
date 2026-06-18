import Foundation

/// SINGLE SOURCE OF TRUTH for the Core Insight teaching-visual images.
///
/// These are pre-generated, cached stills that fill the Core Insight beat card
/// as its BACKGROUND (the coach is at most a small PiP there). Like coach clips
/// and lecture audio, the image is a cached public asset — ~$0 at runtime.
///
/// Files live in the public Supabase Storage bucket `lecture-visuals` under:
///   `{key}.jpg`     e.g.  `firstImpressions.jpg`
///
/// `insightVisual(for:)` derives the key from the lecture's existing `skill`
/// dimension (no new stored field, no curriculum migration). Only three keys
/// are generated today; everything else returns `nil` so the beat falls back to
/// a neutral Aura card.
enum InsightVisualURL {

  /// Currently generated teaching-visual keys. Add a key here once the matching
  /// image has been dropped in the `lecture-visuals` bucket.
  static let available: Set<String> = ["firstImpressions", "presence", "conversationFlow"]

  /// Map a lecture to its teaching-visual key, or `nil` for the Aura fallback.
  /// Derived from `Lecture.skill` so no per-lecture data field is required.
  static func insightVisual(for lecture: Lecture) -> String? {
    let skill = lecture.skill
    let key: String?
    switch skill {
    case "Opening", "Foundations":
      key = "firstImpressions"
    case "Presence", "Frame":
      key = "presence"
    case "Flow", "Texting":
      key = "conversationFlow"
    default:
      // Keyword fallback for skills outside the core set.
      let haystack = "\(lecture.skill) \(lecture.title)".lowercased()
      if haystack.contains("open") || haystack.contains("first") || haystack.contains("impression")
      {
        key = "firstImpressions"
      } else if haystack.contains("present") || haystack.contains("calm")
        || haystack.contains("frame")
      {
        key = "presence"
      } else if haystack.contains("flow") || haystack.contains("convers")
        || haystack.contains("text")
      {
        key = "conversationFlow"
      } else {
        key = nil
      }
    }
    guard let key, available.contains(key) else { return nil }
    return key
  }

  private static var storageBase: String {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    return (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  /// Public URL for a teaching-visual key, or `nil` if the key isn't available.
  static func url(for lecture: Lecture) -> URL? {
    guard let key = insightVisual(for: lecture) else { return nil }
    return url(key: key)
  }

  static func url(key: String) -> URL? {
    let path = "lecture-visuals/\(key).jpg"
    guard let enc = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
      return nil
    }
    return URL(string: "\(storageBase)/storage/v1/object/public/\(enc)")
  }
}
