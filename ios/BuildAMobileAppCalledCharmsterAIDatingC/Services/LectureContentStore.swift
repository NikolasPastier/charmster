import Foundation
import Observation

/// Fetches real lecture content (teaching script, quiz, scenario, coach voices)
/// from the Supabase `lectures` table, seeded from the curriculum bucket.
/// Falls back gracefully when the network or env is unavailable.
@Observable
final class LectureContentStore {
    static let shared = LectureContentStore()

    struct Content: Decodable {
        let id: String
        let track_id: Int
        let lecture_number: Int
        let title: String
        let scenario: String?
        let teaching_content: String?
        let principles: [String]?
        let quiz: [QuizRow]?
        let practice_opener: String?
        let win_condition: String?
        let coach_scripts: [String: String]?
        let success_criteria: String?
    }

    struct QuizRow: Decodable {
        let prompt: String
        let options: [String]
        let correctIndex: Int
    }

    private(set) var byId: [String: Content] = [:]
    private(set) var isLoaded: Bool = false
    private(set) var lastError: String?

    private var supabaseURL: String? {
        ProcessInfo.processInfo.environment["SUPABASE_URL"]?
            .trimmingCharacters(in: .whitespaces).nonEmpty
    }
    private var anonKey: String? {
        let env = ProcessInfo.processInfo.environment
        return (env["SUPABASE_PUBLISHABLE_KEY"] ?? env["SUPABASE_ANON_KEY"])?
            .trimmingCharacters(in: .whitespaces).nonEmpty
    }

    var isConfigured: Bool { supabaseURL != nil && anonKey != nil }

    /// Load all rows. Safe to call repeatedly.
    @MainActor
    func loadIfNeeded() async {
        guard !isLoaded else { return }
        await load()
    }

    @MainActor
    func load() async {
        guard let base = supabaseURL, let key = anonKey else {
            lastError = "Supabase not configured"
            return
        }
        let path = "/rest/v1/lectures?select=id,track_id,lecture_number,title,scenario,teaching_content,principles,quiz,practice_opener,win_condition,coach_scripts,success_criteria&limit=500"
        guard let url = URL(string: base + path) else { return }
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                lastError = "HTTP \( (resp as? HTTPURLResponse)?.statusCode ?? -1)"
                return
            }
            let rows = try JSONDecoder().decode([Content].self, from: data)
            var map: [String: Content] = [:]
            for r in rows { map[r.id] = r }
            self.byId = map
            self.isLoaded = true
            self.lastError = nil
            #if DEBUG
            print("[LectureContentStore] Loaded \(rows.count) lectures")
            #endif
        } catch {
            lastError = error.localizedDescription
            #if DEBUG
            print("[LectureContentStore] load error: \(error)")
            #endif
        }
    }

    // MARK: - Accessors

    func content(for lecture: Lecture) -> Content? { byId[lecture.id] }

    /// Teaching script tuned to the selected coach voice. Falls back to a
    /// concatenated lecture body, then to a generic intro.
    func teachingScript(for lecture: Lecture, coach: CoachMode, fallback: String) -> String {
        guard let c = byId[lecture.id] else { return fallback }
        if let scripts = c.coach_scripts, !scripts.isEmpty,
           let match = scriptMatch(for: coach, in: scripts) {
            return match
        }
        if let body = c.teaching_content, !body.isEmpty {
            return body
        }
        return fallback
    }

    /// Real scenario (Setting / Context / Goal) when available.
    func scenarioText(for lecture: Lecture) -> String {
        if let s = byId[lecture.id]?.scenario, !s.isEmpty { return s }
        return lecture.scenario
    }

    func practiceOpener(for lecture: Lecture) -> String? {
        byId[lecture.id]?.practice_opener?.nonEmpty
    }

    func winCondition(for lecture: Lecture) -> String? {
        byId[lecture.id]?.win_condition?.nonEmpty
    }

    /// Quiz questions adapted to the local `QuizQuestion` type.
    func quiz(for lecture: Lecture) -> [QuizQuestion] {
        guard let rows = byId[lecture.id]?.quiz, !rows.isEmpty else { return [] }
        return rows.map {
            QuizQuestion(prompt: $0.prompt, options: $0.options, correctIndex: $0.correctIndex)
        }
    }

    // MARK: - Coach matching

    private func scriptMatch(for coach: CoachMode, in scripts: [String: String]) -> String? {
        let keys = Array(scripts.keys)
        // Try exact display name first, then contains match on a keyword.
        let keyword: String
        switch coach {
        case .bigBrother:  keyword = "big brother"
        case .scientist:   keyword = "scientist"
        case .alphaMentor: keyword = "alpha"
        case .therapist:   keyword = "therapist"
        case .wingman:     keyword = "wingman"
        }
        if let k = keys.first(where: { $0.lowercased().contains(keyword) }) {
            return scripts[k]
        }
        // Any non-empty script as a safe default.
        return scripts.first { !$0.value.isEmpty }?.value
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
