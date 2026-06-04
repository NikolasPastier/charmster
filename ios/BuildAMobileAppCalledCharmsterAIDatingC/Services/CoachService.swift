import Foundation

/// Calls the deployed Supabase Edge Functions: `coach` and `generate_script`.
/// Keeps all OpenAI usage server-side. Reads client-safe config from the env.
struct CoachService {
    struct CoachResponse: Decodable {
        let coach_output: String
        let citations: [String]?
        let mode: String?
    }

    enum CoachError: LocalizedError {
        case notConfigured
        case http(Int, String)
        case decoding

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Coach backend not configured."
            case .http(let code, let body): return "Coach call failed (\(code)). \(body)"
            case .decoding: return "Could not read coach response."
            }
        }
    }

    /// Roadmap node IDs that match the seeded `knowledge_chunks.roadmap_node`.
    enum RoadmapNode: String {
        case firstImpressions = "first_impressions"
        case conversationFlow = "conversation_flow"
        case deepConnection = "deep_connection"
        case readingSignals = "reading_signals"
        case bodyPresence = "body_presence"
        case handlingRejection = "handling_rejection"
        case personalization
    }

    static let shared = CoachService()

    private var supabaseURL: String? {
        let env = ProcessInfo.processInfo.environment
        return env["SUPABASE_URL"]?.trimmingCharacters(in: .whitespaces).nonEmpty
    }

    private var anonKey: String? {
        let env = ProcessInfo.processInfo.environment
        return (env["SUPABASE_PUBLISHABLE_KEY"] ?? env["SUPABASE_ANON_KEY"])?
            .trimmingCharacters(in: .whitespaces).nonEmpty
    }

    var isConfigured: Bool { supabaseURL != nil && anonKey != nil }

    /// POST /functions/v1/coach
    func coach(node: RoadmapNode,
               userInput: String,
               mode: CoachMode) async throws -> CoachResponse {
        guard let base = supabaseURL, let key = anonKey else { throw CoachError.notConfigured }
        guard let url = URL(string: "\(base)/functions/v1/coach") else { throw CoachError.notConfigured }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue(key, forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "user_id": NSNull(),
            "roadmap_node": node.rawValue,
            "user_input": userInput,
            "coach_mode": mode.rawValue
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw CoachError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            let txt = String(data: data, encoding: .utf8) ?? ""
            throw CoachError.http(http.statusCode, txt)
        }
        do {
            return try JSONDecoder().decode(CoachResponse.self, from: data)
        } catch {
            throw CoachError.decoding
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
