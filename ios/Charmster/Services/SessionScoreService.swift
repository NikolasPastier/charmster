import Foundation

/// Client for the `session_score` Supabase Edge Function.
/// Called once at session end — gpt-4o-mini, ~500 tokens output.
/// Returns nil on any failure; SessionScorer falls back to proxy values.
enum SessionScoreService {

  struct Result {
    let responsiveness: Int  // 0..100 — content-based
    let calibration: Int     // 0..100 — cue-reading
    let comfort: Int         // 0..100 — safety + space
    let interest: Int        // 0..100 — her engagement
    let spark: Int           // 0..100 — playful tension
    let respect: Int         // 0..100 — autonomy + no pressure
    let reactionLine: String
    let strengths: [String]
    let fixes: [String]
  }

  static func judge(
    transcript: String,
    durationSeconds: Int,
    meanLatencySeconds: Double?,
    voiceEnergy: Double?,
    synchrony: Double?,
    lectureScenario: String?,
    winCondition: String?
  ) async -> Result? {
    let env = ProcessInfo.processInfo.environment
    guard
      let urlString = env["SUPABASE_URL"],
      let anonKey = env["SUPABASE_PUBLISHABLE_KEY"] ?? env["SUPABASE_ANON_KEY"],
      let base = URL(string: urlString)
    else { return nil }

    let endpoint = base.appendingPathComponent("functions/v1/session_score")
    var req = URLRequest(url: endpoint)
    req.httpMethod = "POST"
    req.timeoutInterval = 20
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    req.setValue(anonKey, forHTTPHeaderField: "apikey")

    var payload: [String: Any] = [
      "transcript": transcript,
      "duration_seconds": durationSeconds,
    ]
    if let lat = meanLatencySeconds { payload["mean_latency_seconds"] = lat }
    if let ve = voiceEnergy { payload["voice_energy"] = ve }
    if let sy = synchrony { payload["synchrony"] = sy }
    if let sc = lectureScenario { payload["lecture_scenario"] = sc }
    if let wc = winCondition { payload["win_condition"] = wc }

    guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
    req.httpBody = body

    do {
      let (data, response) = try await URLSession.shared.data(for: req)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        return nil
      }
      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
      }
      func int(_ key: String) -> Int { (json[key] as? Int) ?? 50 }
      return Result(
        responsiveness: int("responsiveness"),
        calibration: int("calibration"),
        comfort: int("comfort"),
        interest: int("interest"),
        spark: int("spark"),
        respect: int("respect"),
        reactionLine: (json["reactionLine"] as? String) ?? "",
        strengths: (json["strengths"] as? [String]) ?? [],
        fixes: (json["fixes"] as? [String]) ?? []
      )
    } catch {
      return nil
    }
  }
}
