import Foundation

/// A path Capstone — the final node of each track. Multi-stage simulated date.
struct Capstone: Identifiable, Hashable {
    let id: String              // "capstone-t2"
    let trackId: Int
    let name: String
    let scenario: String
    let stages: [CapstoneStage]
    let textOnly: Bool          // track 10 = text only
}

enum CapstoneStage: String, CaseIterable, Identifiable, Hashable {
    case open       = "Open"
    case smallTalk  = "Small talk"
    case deepen     = "Deepen"
    case flirt      = "Flirt"
    case close      = "Close"
    var id: String { rawValue }
}

struct CapstoneProgress: Hashable, Codable {
    var passedOnce: Bool = false
    var bestScore: Int = 0
    var firstPassAt: Date? = nil
    var pathMasteryBadge: Bool = false
}

enum CapstoneCatalog {
    /// Per-track capstone names (spec: 1...13).
    private static let names: [Int: String] = [
        1: "The Warm-Up",
        2: "The Approach",
        3: "The Flowing Chat",
        4: "The Playful Exchange",
        5: "The Read",
        6: "The Grounded Date",
        7: "The Real Conversation",
        8: "The Cool Head",
        9: "Your Secure Self",
        10: "The Full Thread",
        11: "The Profile Audit",
        12: "The Whole Date",
        13: "The Next Chapter",
        // Inclusive expansion tracks (Step 9):
        14: "Speaking My Truth",
        15: "Open Doors",
        16: "Cues & Scripts",
        17: "Steady Through the Spike",
    ]

    private static let scenarios: [Int: String] = [
        1: "A full first conversation where you stay grounded from hello to goodbye.",
        2: "Approach, hold the energy, exchange info, exit cleanly.",
        3: "Keep a flowing café chat without forcing momentum.",
        4: "A playful exchange that earns real laughter without performing.",
        5: "She gives mixed signals — read it, name it kindly, recover.",
        6: "Whole evening at a quiet bar. Stay grounded across stages.",
        7: "She opens up. Match her depth without flooding.",
        8: "High-pressure scene — keep the cool head you've trained.",
        9: "A first conversation as your fully personalized self.",
        10: "An entire text thread from match to date set.",
        11: "Audit and rebuild a dating profile, end-to-end.",
        12: "The full date — propose, arrive, lead, close.",
        13: "Third date energy — name the thing, real and calm.",
        14: "An honest conversation about who you are and what you want.",
        15: "Disclose, set the date, navigate logistics with confidence.",
        16: "Read the cues, run the script, stay regulated.",
        17: "Pre-date anxiety peaks — calm the wave, show up like yourself.",
    ]

    static func capstone(for trackId: Int) -> Capstone? {
        guard let name = names[trackId], let scenario = scenarios[trackId] else { return nil }
        return Capstone(
            id: "capstone-t\(trackId)",
            trackId: trackId,
            name: name,
            scenario: scenario,
            stages: CapstoneStage.allCases,
            textOnly: trackId == 10
        )
    }

    /// Capstone XP: round((100 + 60*(score/100)) * tier).
    static func capstoneXP(sessionScore: Int, tier: DifficultyTier) -> Int {
        let raw = 100.0 + 60.0 * (Double(sessionScore) / 100.0)
        return Int((raw * tier.multiplier).rounded())
    }

    /// Replay XP after first pass: round(0.25 * capstoneXP).
    static func replayXP(sessionScore: Int, tier: DifficultyTier) -> Int {
        Int((Double(capstoneXP(sessionScore: sessionScore, tier: tier)) * 0.25).rounded())
    }

    /// One-time first-pass bonus.
    static let firstPassBonusXP: Int = 500
}
