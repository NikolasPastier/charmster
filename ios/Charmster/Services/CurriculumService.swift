import Foundation

/// Fetches tracks + lectures from Supabase (PostgREST) and overlays them onto
/// `Curriculum`. On any failure the bundled `Resources/curriculum.json` remains
/// in effect, so the app still has a real curriculum to render.
@MainActor
final class CurriculumService {

  static let shared = CurriculumService()

  private var inflight: Task<Void, Never>?

  /// Kick off a one-shot refresh. Safe to call multiple times; reuses the
  /// inflight task. Result is overlaid onto `Curriculum`.
  func refreshIfNeeded() {
    guard Curriculum.source == .bundle else { return }
    if inflight != nil { return }
    inflight = Task { [weak self] in
      await self?.runFetch()
      self?.inflight = nil
    }
  }

  private func runFetch() async {
    guard let base = baseURL() else {
      TenXPreviewSupport.log("[Curriculum] no SUPABASE_URL — using bundled curriculum")
      return
    }
    guard let anon = anonKey() else {
      TenXPreviewSupport.log("[Curriculum] no SUPABASE anon key — using bundled curriculum")
      return
    }
    do {
      async let tracks = fetchTracks(base: base, anon: anon)
      async let lectures = fetchLectures(base: base, anon: anon)
      let (t, l) = try await (tracks, lectures)
      guard !t.isEmpty, !l.isEmpty else {
        TenXPreviewSupport.log("[Curriculum] remote returned empty — keeping bundle")
        return
      }
      Curriculum.overlayRemote(tracks: t, lectures: l)
      TenXPreviewSupport.log(
        "[Curriculum] overlaid \(t.count) tracks · \(l.count) lectures from Supabase")
    } catch {
      TenXPreviewSupport.log(
        "[Curriculum] fetch failed: \(error.localizedDescription) — using bundle")
    }
  }

  // MARK: - REST

  private func fetchTracks(base: URL, anon: String) async throws -> [Track] {
    let url =
      base
      .appendingPathComponent("rest/v1/tracks")
      .appending(queryItems: [
        URLQueryItem(
          name: "select",
          value: "id,slug,emoji,title,subtitle,core_question,symbol,order,access_default"),
        URLQueryItem(name: "order", value: "order.asc"),
      ])
    let data = try await get(url, anon: anon)
    let rows = try JSONDecoder().decode([TrackRow].self, from: data)
    return rows.map { row in
      Track(
        id: row.id,
        slug: row.slug,
        title: row.title,
        subtitle: row.subtitle,
        coreQuestion: row.core_question,
        emoji: row.emoji,
        symbol: row.symbol,
        order: row.order,
        accessDefault: LectureAccess(rawValue: row.access_default) ?? .pro,
        lectureCount: 0  // resolved after lectures load
      )
    }
  }

  private func fetchLectures(base: URL, anon: String) async throws -> [Lecture] {
    let url =
      base
      .appendingPathComponent("rest/v1/lectures")
      .appending(queryItems: [
        URLQueryItem(
          name: "select",
          value: "id,track_id,lecture_number,title,scenario,access,format,minutes,skill,is_capstone"
        ),
        URLQueryItem(name: "order", value: "track_id.asc,lecture_number.asc"),
      ])
    let data = try await get(url, anon: anon)
    let rows = try JSONDecoder().decode([LectureRow].self, from: data)
    return rows.map { row in
      let access = LectureAccess(rawValue: row.access ?? "pro") ?? .pro
      let format = LectureFormat(rawValue: row.format ?? "video") ?? .video
      let canonicalId: String
      if row.is_capstone == true {
        canonicalId = "\(row.track_id).capstone"
      } else {
        canonicalId = "\(row.track_id).\(row.lecture_number)"
      }
      return Lecture(
        id: canonicalId,
        trackId: row.track_id,
        number: row.lecture_number,
        title: row.title,
        scenario: row.scenario ?? row.title,
        minutes: row.minutes ?? 5,
        skill: row.skill ?? "Practice",
        isCapstone: row.is_capstone ?? false,
        access: access,
        format: format
      )
    }
  }

  private func get(_ url: URL, anon: String) async throws -> Data {
    var req = URLRequest(url: url)
    req.setValue(anon, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, resp) = try await URLSession.shared.data(for: req)
    if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw NSError(
        domain: "Curriculum", code: http.statusCode,
        userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
    }
    return data
  }

  // MARK: - Env

  private func baseURL() -> URL? {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
    let raw = env.isEmpty ? "https://uvjtrhvhldeeslgnvhyd.supabase.co" : env
    return URL(string: raw.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
  }

  private func anonKey() -> String? {
    let keys = ["SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY"]
    for k in keys {
      if let v = ProcessInfo.processInfo.environment[k], !v.isEmpty { return v }
    }
    return nil
  }

  // MARK: - REST row DTOs

  private struct TrackRow: Decodable {
    let id: Int
    let slug: String
    let emoji: String
    let title: String
    let subtitle: String
    let core_question: String
    let symbol: String
    let order: Int
    let access_default: String
  }

  private struct LectureRow: Decodable {
    let id: String
    let track_id: Int
    let lecture_number: Int
    let title: String
    let scenario: String?
    let access: String?
    let format: String?
    let minutes: Int?
    let skill: String?
    let is_capstone: Bool?
  }
}
