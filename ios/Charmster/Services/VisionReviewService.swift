import Foundation

/// Minimal client for the `vision_review` Supabase Edge Function.
///
/// Posts a single JPEG frame + optional transcript snippet and returns
/// face/body/warmth scores. Returns `nil` on any failure (missing config,
/// network error, non-200 response, or unparseable payload) so the live
/// pipeline silently falls back to mock signals.
enum VisionReviewService {

  struct Result {
    let face: Int  // 0..100
    let body: Int  // 0..100
    let warmth: Double  // 0..1
  }

  static func score(
    jpeg: Data,
    userId: String,
    sessionId: String?,
    lectureId: String?,
    transcriptSnippet: String?
  ) async -> Result? {
    let env = ProcessInfo.processInfo.environment
    guard
      let urlString = env["SUPABASE_URL"],
      let anonKey = env["SUPABASE_PUBLISHABLE_KEY"] ?? env["SUPABASE_ANON_KEY"],
      let base = URL(string: urlString)
    else { return nil }

    let endpoint = base.appendingPathComponent("functions/v1/vision_review")
    var req = URLRequest(url: endpoint)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    req.setValue(anonKey, forHTTPHeaderField: "apikey")

    let payload: [String: Any] = [
      "user_id": userId,
      "session_id": sessionId ?? "",
      "lecture_id": lectureId ?? "",
      "transcript_snippet": transcriptSnippet ?? "",
      "image_base64": jpeg.base64EncodedString(),
    ]
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
    req.httpBody = body

    do {
      let (data, response) = try await URLSession.shared.data(for: req)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        return nil
      }
      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
      }
      let face = (json["face"] as? Int) ?? Int((json["face"] as? Double) ?? -1)
      let bodyScore = (json["body"] as? Int) ?? Int((json["body"] as? Double) ?? -1)
      let warmth = (json["warmth"] as? Double) ?? Double((json["warmth"] as? Int) ?? -1)
      guard face >= 0, bodyScore >= 0, warmth >= 0 else { return nil }
      return Result(
        face: max(0, min(100, face)),
        body: max(0, min(100, bodyScore)),
        warmth: max(0, min(1, warmth)))
    } catch {
      return nil
    }
  }
}
