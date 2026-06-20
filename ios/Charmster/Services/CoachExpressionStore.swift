import Foundation

// MARK: - ExpressionPose

/// The five expression stills every coach has in Supabase Storage
/// at `Avatars/Coaches/{id}/expressions/`.
enum ExpressionPose: String, CaseIterable {
  case neutral
  case intrigued
  case focused
  case warm
  case thoughtful

  static func pose(for kind: LectureBeatKind) -> ExpressionPose {
    switch kind {
    case .hook:            return .intrigued
    case .coreInsight:     return .focused
    case .goodVsBad:       return .thoughtful
    case .recallCheck:     return .neutral
    case .takeawayHandoff: return .warm
    }
  }
}

// MARK: - CoachExpressionStore

/// Resolves + caches the five expression-still URLs per coach from
/// `Avatars/Coaches/{id}/expressions/` in Supabase Storage via the list API.
///
/// Call `prefetch(coachId:)` before the lecture starts; `url(for:pose:)`
/// returns the cached URL synchronously once resolved. Gracefully returns nil
/// (and lets the video fallback show through) when offline or not yet resolved.
@Observable
@MainActor
final class CoachExpressionStore {

  static let shared = CoachExpressionStore()

  private var cache: [String: [ExpressionPose: URL]] = [:]
  private var inflight: [String: Task<Void, Never>] = [:]

  // MARK: - Public

  func url(for coachId: String, pose: ExpressionPose) -> URL? {
    cache[storageId(coachId)]?[pose]
  }

  func prefetch(coachId: String) {
    let id = storageId(coachId)
    guard cache[id] == nil, inflight[id] == nil else { return }
    inflight[id] = Task {
      await resolve(id)
      inflight[id] = nil
    }
  }

  // MARK: - Private

  private func resolve(_ id: String) async {
    guard let base = storageBase, let key = anonKey else { return }
    guard let listURL = URL(string: "\(base)/storage/v1/object/list/Avatars") else { return }

    var req = URLRequest(url: listURL)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    guard let body = try? JSONEncoder().encode(["prefix": "Coaches/\(id)/expressions"]) else { return }
    req.httpBody = body

    guard let (data, _) = try? await URLSession.shared.data(for: req) else { return }
    guard let files = try? JSONDecoder().decode([StorageFile].self, from: data) else { return }

    var resolved: [ExpressionPose: URL] = [:]
    for pose in ExpressionPose.allCases {
      let matches = files.filter { $0.name.lowercased().contains(pose.rawValue) }
      guard let best = matches.max(by: { trailingNumber($0.name) < trailingNumber($1.name) }) else {
        continue
      }
      let path = "Avatars/Coaches/\(id)/expressions/\(best.name)"
      guard let enc = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "\(base)/storage/v1/object/public/\(enc)") else { continue }
      resolved[pose] = url
    }

    if !resolved.isEmpty { cache[id] = resolved }
  }

  private func trailingNumber(_ name: String) -> Int {
    let digits = name.reversed().prefix(while: { $0.isNumber })
    return Int(String(digits.reversed())) ?? 0
  }

  private func storageId(_ coachId: String) -> String {
    coachId == "dr_ray" ? "ray" : coachId
  }

  private var storageBase: String? {
    let env = ProcessInfo.processInfo.environment
    let s = env["SUPABASE_URL"] ?? "https://uvjtrhvhldeeslgnvhyd.supabase.co"
    let trimmed = s.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return trimmed.isEmpty ? nil : trimmed
  }

  private var anonKey: String? {
    let env = ProcessInfo.processInfo.environment
    return env["SUPABASE_PUBLISHABLE_KEY"] ?? env["SUPABASE_ANON_KEY"]
  }

  private struct StorageFile: Decodable { let name: String }
}
