import Foundation

/// Hardcoded curriculum. 4 tracks × (4 lectures + 1 capstone) = 20 lectures total.
/// Step 4 requirement: every track ends with a Capstone node.
enum Curriculum {

    static let tracks: [Track] = Track.library

    static let lectures: [Lecture] = build()

    static func lectures(in trackId: Int) -> [Lecture] {
        lectures.filter { $0.trackId == trackId }.sorted { $0.number < $1.number }
    }

    static func lecture(id: String) -> Lecture? {
        lectures.first { $0.id == id }
    }

    static func capstone(in trackId: Int) -> Lecture? {
        lectures.first { $0.trackId == trackId && $0.isCapstone }
    }

    // MARK: - Build

    private static func build() -> [Lecture] {
        var all: [Lecture] = []
        for t in tracks {
            let entries = entriesFor(track: t.id)
            for (idx, entry) in entries.enumerated() {
                all.append(Lecture(
                    id: "t\(t.id)_l\(idx + 1)",
                    trackId: t.id,
                    number: idx + 1,
                    title: entry.title,
                    scenario: entry.scenario,
                    minutes: entry.minutes,
                    skill: entry.skill,
                    isCapstone: entry.isCapstone
                ))
            }
        }
        return all
    }

    private struct Entry {
        let title: String
        let scenario: String
        let minutes: Int
        let skill: String
        let isCapstone: Bool
    }

    // swiftlint:disable function_body_length
    private static func entriesFor(track: Int) -> [Entry] {
        switch track {
        case 0:
            return [
                .init(title: "The 3-second open",
                      scenario: "You're in line for coffee. She's two people ahead.",
                      minutes: 4, skill: "Opening", isCapstone: false),
                .init(title: "Holding eye contact",
                      scenario: "She looks up from her phone and clocks you.",
                      minutes: 4, skill: "Presence", isCapstone: false),
                .init(title: "Graceful exit",
                      scenario: "The conversation peaked. Now what.",
                      minutes: 5, skill: "Exits", isCapstone: false),
                .init(title: "Reading interest",
                      scenario: "Subtle signals across a crowded café.",
                      minutes: 5, skill: "Calibration", isCapstone: false),
                .init(title: "Capstone — First coffee, end to end",
                      scenario: "Open, hold a real conversation, and exit cleanly.",
                      minutes: 9, skill: "Beginner capstone", isCapstone: true)
            ]
        case 1:
            return [
                .init(title: "Callbacks",
                      scenario: "She made a joke 4 minutes ago. Bring it back.",
                      minutes: 5, skill: "Flow", isCapstone: false),
                .init(title: "Storytelling tempo",
                      scenario: "Tell a 90-second story and land the beat.",
                      minutes: 6, skill: "Tempo", isCapstone: false),
                .init(title: "Playful disagreement",
                      scenario: "She says pineapple belongs on pizza.",
                      minutes: 5, skill: "Banter", isCapstone: false),
                .init(title: "Asking better questions",
                      scenario: "Move past 'so what do you do.'",
                      minutes: 5, skill: "Curiosity", isCapstone: false),
                .init(title: "Capstone — A full bar conversation",
                      scenario: "Hold 8 minutes of real flow without filler.",
                      minutes: 10, skill: "Conversation capstone", isCapstone: true)
            ]
        case 2:
            return [
                .init(title: "Frame holding",
                      scenario: "She tests your reaction. Don't flinch.",
                      minutes: 5, skill: "Frame", isCapstone: false),
                .init(title: "Vulnerability without leak",
                      scenario: "Share something real without dumping.",
                      minutes: 6, skill: "Presence", isCapstone: false),
                .init(title: "Saying no warmly",
                      scenario: "She asks for a favor you can't give today.",
                      minutes: 5, skill: "Standards", isCapstone: false),
                .init(title: "Owning silence",
                      scenario: "Three seconds of nothing. Don't fill it.",
                      minutes: 5, skill: "Presence", isCapstone: false),
                .init(title: "Capstone — Dinner with friction",
                      scenario: "She pushes; you stay grounded and warm.",
                      minutes: 10, skill: "Confidence capstone", isCapstone: true)
            ]
        case 3:
            return [
                .init(title: "Reading subtext",
                      scenario: "What she didn't say is louder than what she did.",
                      minutes: 6, skill: "Reading", isCapstone: false),
                .init(title: "Matching energy floor",
                      scenario: "She's quiet. Don't go bigger.",
                      minutes: 5, skill: "Calibration", isCapstone: false),
                .init(title: "Repair after a miss",
                      scenario: "Your joke landed wrong. Recover.",
                      minutes: 5, skill: "Repair", isCapstone: false),
                .init(title: "Closing the loop",
                      scenario: "Time to ask for the next step.",
                      minutes: 5, skill: "Closing", isCapstone: false),
                .init(title: "Capstone — A full date",
                      scenario: "Meet, eat, read her, close the loop.",
                      minutes: 10, skill: "Mastery capstone", isCapstone: true)
            ]
        default:
            return []
        }
    }
    // swiftlint:enable function_body_length
}
