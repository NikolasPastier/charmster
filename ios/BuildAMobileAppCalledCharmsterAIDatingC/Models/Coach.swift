import SwiftUI

enum CoachMode: String, Codable, CaseIterable, Identifiable {
    case hypeMan = "hype_man"
    case wingman = "wingman"
    case hardTruth = "hard_truth"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hypeMan: return "The Hype Man"
        case .wingman: return "The Wingman"
        case .hardTruth: return "The Hard Truth"
        }
    }

    var tagline: String {
        switch self {
        case .hypeMan: return "Encouraging · celebrates every win"
        case .wingman: return "Casual · real · trusted friend"
        case .hardTruth: return "Direct · no filter · zero sugar"
        }
    }

    var icon: String {
        switch self {
        case .hypeMan: return "flame.fill"
        case .wingman: return "person.2.fill"
        case .hardTruth: return "bolt.fill"
        }
    }
}

enum QuizChallenge: String, CaseIterable, Identifiable {
    case openers = "Starting conversations"
    case threading = "Keeping them going"
    case dates = "First dates"
    case signals = "Reading signals"
    var id: String { rawValue }
}

enum QuizArena: String, CaseIterable, Identifiable {
    case apps = "Dating apps"
    case person = "In person"
    case both = "Both"
    var id: String { rawValue }
}

enum QuizCadence: String, CaseIterable, Identifiable {
    case five = "5 mins"
    case ten = "10 mins"
    case fifteen = "15+ mins"
    var id: String { rawValue }
}

struct QuizResult {
    var challenge: QuizChallenge?
    var arena: QuizArena?
    var coach: CoachMode?
    var cadence: QuizCadence?

    var isComplete: Bool {
        challenge != nil && arena != nil && coach != nil && cadence != nil
    }

    // Deterministic "charm score" feels personal but always shows room to grow.
    var charmScore: Int {
        var score = 28
        if challenge == .signals { score += 4 }
        if arena == .both { score += 2 }
        if cadence == .fifteen { score += 6 } else if cadence == .ten { score += 3 }
        return min(score, 42)
    }
}
