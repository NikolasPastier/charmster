import Foundation
import SwiftUI

enum QuestPath: String, CaseIterable, Codable, Identifiable {
    case beginner, conversation, confidence, mastery
    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .conversation: return "Conversation"
        case .confidence: return "Confidence"
        case .mastery: return "Mastery"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: return "Foundations of every encounter"
        case .conversation: return "Hold attention. Build pull."
        case .confidence: return "Own the room. Anywhere."
        case .mastery: return "Stress-tested in the wild."
        }
    }

    var color: Color {
        switch self {
        case .beginner: return Theme.accent
        case .conversation: return Theme.pathBlue
        case .confidence: return Theme.coral
        case .mastery: return Theme.pathGold
        }
    }
}

enum QuestStatus: String, Codable {
    case completed, active, locked
}

struct Quest: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let path: QuestPath
    let orderIndex: Int
    let xpReward: Int
    let estimatedMinutes: Int
    let skillTag: String
    let isBossFight: Bool
    let contentPreview: String
    var status: QuestStatus

    static func == (lhs: Quest, rhs: Quest) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Quest {
    static let sampleRoadmap: [Quest] = [
        // Beginner
        Quest(id: UUID(), title: "First Impressions",
              description: "Learn the 3-second rule that hooks attention before you speak.",
              path: .beginner, orderIndex: 1, xpReward: 50, estimatedMinutes: 5,
              skillTag: "Openers", isBossFight: false,
              contentPreview: "3 text drills + 1 AI conversation",
              status: .completed),
        Quest(id: UUID(), title: "Keeping It Going",
              description: "Turn dry replies into real conversations with momentum.",
              path: .beginner, orderIndex: 2, xpReward: 50, estimatedMinutes: 5,
              skillTag: "Threading", isBossFight: false,
              contentPreview: "4 text drills + scenario practice",
              status: .completed),
        Quest(id: UUID(), title: "Reading the Room",
              description: "Spot interest signals — and disinterest — before they speak.",
              path: .beginner, orderIndex: 3, xpReward: 75, estimatedMinutes: 7,
              skillTag: "Awareness", isBossFight: false,
              contentPreview: "2 scenarios + AI feedback",
              status: .active),
        Quest(id: UUID(), title: "The Coffee Shop",
              description: "A live simulation. One shot. Approach, open, exchange numbers.",
              path: .beginner, orderIndex: 4, xpReward: 200, estimatedMinutes: 12,
              skillTag: "Boss Fight", isBossFight: true,
              contentPreview: "Live voice simulation · scored",
              status: .locked),
        // Conversation
        Quest(id: UUID(), title: "Texting Missions",
              description: "Upload dead conversations. Get an autopsy and three reply tracks.",
              path: .conversation, orderIndex: 5, xpReward: 75, estimatedMinutes: 6,
              skillTag: "Texting", isBossFight: false,
              contentPreview: "Screenshot analysis + reply templates",
              status: .locked),
        Quest(id: UUID(), title: "Humor & Wit",
              description: "Build a humor reflex without trying to be a comedian.",
              path: .conversation, orderIndex: 6, xpReward: 75, estimatedMinutes: 8,
              skillTag: "Charisma", isBossFight: false,
              contentPreview: "5 callback drills",
              status: .locked),
        Quest(id: UUID(), title: "Deep Questions",
              description: "Move past small talk in three exchanges, without it feeling weird.",
              path: .conversation, orderIndex: 7, xpReward: 100, estimatedMinutes: 8,
              skillTag: "Connection", isBossFight: false,
              contentPreview: "Voice sim + scoring",
              status: .locked),
        Quest(id: UUID(), title: "First Date Conversation",
              description: "A full simulated first date. Land the second date.",
              path: .conversation, orderIndex: 8, xpReward: 250, estimatedMinutes: 15,
              skillTag: "Boss Fight", isBossFight: true,
              contentPreview: "Live voice simulation · scored",
              status: .locked),
        // Confidence
        Quest(id: UUID(), title: "Body Language Basics",
              description: "How to occupy space without overdoing it.",
              path: .confidence, orderIndex: 9, xpReward: 100, estimatedMinutes: 8,
              skillTag: "Presence", isBossFight: false,
              contentPreview: "Posture drills + breakdown",
              status: .locked),
        Quest(id: UUID(), title: "Vocal Presence",
              description: "Slow down, drop in, and let your voice do the work.",
              path: .confidence, orderIndex: 10, xpReward: 100, estimatedMinutes: 8,
              skillTag: "Voice", isBossFight: false,
              contentPreview: "Voice sim + tone feedback",
              status: .locked),
        Quest(id: UUID(), title: "Handling Rejection",
              description: "Stay grounded when it doesn't land. Keep your night.",
              path: .confidence, orderIndex: 11, xpReward: 125, estimatedMinutes: 10,
              skillTag: "Resilience", isBossFight: false,
              contentPreview: "3 scenarios + reflection",
              status: .locked),
        Quest(id: UUID(), title: "The Blind Date",
              description: "Walk in cold. Build chemistry from zero. No script.",
              path: .confidence, orderIndex: 12, xpReward: 300, estimatedMinutes: 18,
              skillTag: "Boss Fight", isBossFight: true,
              contentPreview: "Live voice simulation · scored",
              status: .locked),
        // Mastery
        Quest(id: UUID(), title: "Real-World Scenarios",
              description: "Bar, gym, bookstore, airport. Pick a setting and run it.",
              path: .mastery, orderIndex: 13, xpReward: 200, estimatedMinutes: 15,
              skillTag: "Anywhere", isBossFight: false,
              contentPreview: "4 scenarios on rotation",
              status: .locked),
        Quest(id: UUID(), title: "Leaderboard Unlock",
              description: "Compete with other Charmsters. Weekly resets.",
              path: .mastery, orderIndex: 14, xpReward: 500, estimatedMinutes: 5,
              skillTag: "Trophy", isBossFight: true,
              contentPreview: "Unlocks global ranking",
              status: .locked),
    ]
}
