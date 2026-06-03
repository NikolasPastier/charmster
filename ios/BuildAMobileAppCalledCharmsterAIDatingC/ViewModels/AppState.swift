import SwiftUI
import Observation

@Observable
final class AppState {
    // Onboarding gate
    var hasOnboarded: Bool = false

    // Profile
    var username: String = "You"
    var coachMode: CoachMode = .wingman
    var xp: Int = 240
    var streak: Int = 3
    var charmScore: Int = 34
    var level: Int = 4
    var levelTitle: String = "Smooth Talker"
    var weakArea: String = "Starting conversations"

    // Roadmap
    var quests: [Quest] = Quest.sampleRoadmap

    // Subscription
    var isPro: Bool = false

    // MARK: - Actions
    func applyQuizResult(_ result: QuizResult) {
        if let coach = result.coach { coachMode = coach }
        if let challenge = result.challenge { weakArea = challenge.rawValue }
        charmScore = result.charmScore
        hasOnboarded = true
    }

    func completeQuest(_ quest: Quest) {
        guard let idx = quests.firstIndex(of: quest) else { return }
        quests[idx].status = .completed
        xp += quest.xpReward
        // Unlock next
        if idx + 1 < quests.count, quests[idx + 1].status == .locked {
            quests[idx + 1].status = .active
        }
    }

    var nextQuest: Quest? {
        quests.first { $0.status == .active } ?? quests.first { $0.status == .locked }
    }

    var completedCount: Int { quests.filter { $0.status == .completed }.count }

    var pathProgress: Double {
        let total = Double(quests.count)
        let done = Double(completedCount)
        return total > 0 ? done / total : 0
    }
}
