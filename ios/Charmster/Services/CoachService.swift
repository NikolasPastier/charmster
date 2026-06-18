import Foundation

/// Thin client for the Supabase `coach` Edge Function. Mirrors the same
/// pattern the future video+voice review pipeline will use.
struct CoachService {

  static var baseURL: URL? {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    let base = (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return URL(string: "\(base)/functions/v1/coach")
  }

  static var anonKey: String? {
    let env = ProcessInfo.processInfo.environment
    return env["SUPABASE_PUBLISHABLE_KEY"] ?? env["SUPABASE_ANON_KEY"]
  }

  struct Request: Encodable {
    let lectureId: String?
    let coachStyle: String
    let transcript: String?
    let kind: String  // "teaching" | "debrief" | "tip"
    /// Compact personalization summary (goal, experience, attachment lean,
    /// focus areas, preferred tone). Built from `AppState.coachPersonalizationSummary`.
    /// TODO(backend): the `coach` edge function must interpolate this into the
    /// system prompt once auth + profiles land.
    var personalization: String? = nil
  }

  struct Response: Decodable {
    let text: String?
  }

  /// Fire-and-return; offline-safe. Returns `nil` on any failure so callers
  /// can fall back to local content.
  static func ask(_ req: Request) async -> String? {
    guard let url = baseURL, let key = anonKey else { return nil }
    var r = URLRequest(url: url)
    r.httpMethod = "POST"
    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
    r.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    r.setValue(key, forHTTPHeaderField: "apikey")
    r.httpBody = try? JSONEncoder().encode(req)
    do {
      let (data, resp) = try await URLSession.shared.data(for: r)
      guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        return nil
      }
      return try JSONDecoder().decode(Response.self, from: data).text
    } catch {
      return nil
    }
  }
}
