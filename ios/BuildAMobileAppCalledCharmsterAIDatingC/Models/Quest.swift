import Foundation

/// Charmster curriculum models. Mocked locally; will sync to Supabase later.

struct Track: Identifiable, Hashable {
    let id: Int            // 0...13
    let number: Int
    let name: String
    let blurb: String
    let symbol: String     // SF Symbol
}

struct Lecture: Identifiable, Hashable {
    let id: String         // "t2-l3"
    let trackId: Int
    let number: Int
    let title: String
    let scenario: String
    let minutes: Int
    /// Per-dimension weight profile. Texting lectures zero voice/face/body.
    let weights: WeightProfile
}

struct WeightProfile: Hashable {
    var responsiveness: Double = 1
    var voice: Double = 1
    var face: Double = 1
    var body: Double = 1
    var synchrony: Double = 1
    var calibration: Double = 1

    static let standard = WeightProfile()
    static let texting  = WeightProfile(responsiveness: 1.5, voice: 0, face: 0, body: 0,
                                        synchrony: 0.8, calibration: 1.2)
}

enum LectureState { case locked, current, mastered }

struct LectureProgress: Hashable {
    var quizScore: Int = 0   // 0...3
    var practiced: Bool = false
    var mastered: Bool { quizScore >= 2 && practiced }
}

// MARK: - Quiz

struct QuizQuestion: Identifiable, Hashable {
    let id = UUID()
    let prompt: String
    let options: [String]
    let correctIndex: Int
}

// MARK: - Session result (post-practice)

struct SessionResult: Hashable {
    /// 6 dimension scores 0-100
    var responsiveness: Int
    var voice: Int
    var face: Int
    var body: Int
    var synchrony: Int
    var calibration: Int

    /// 4 "how she'd feel" meters 0-100
    var comfort: Int
    var interest: Int
    var spark: Int
    var respect: Int

    var sessionScore: Int
    var reaction: String
    var strengths: [String]
    var fixes: [String]
    var xpEarned: Int
    var coinsEarned: Int
}

// MARK: - Curriculum (seeded)

enum Curriculum {
    static let tracks: [Track] = [
        Track(id: 0,  number: 0,  name: "Starter Assessment",
              blurb: "Find your starting point.",          symbol: "sparkles"),
        Track(id: 1,  number: 1,  name: "Foundations",
              blurb: "Mindset & self-worth.",              symbol: "mountain.2.fill"),
        Track(id: 2,  number: 2,  name: "First Impressions",
              blurb: "Approaches & openers.",              symbol: "hand.wave.fill"),
        Track(id: 3,  number: 3,  name: "Conversation",
              blurb: "Keep it flowing.",                   symbol: "bubble.left.and.bubble.right.fill"),
        Track(id: 4,  number: 4,  name: "Humor",
              blurb: "Be playful, not performative.",      symbol: "face.smiling.fill"),
        Track(id: 5,  number: 5,  name: "Reading Signals",
              blurb: "Notice the subtext.",                symbol: "waveform.path.ecg"),
        Track(id: 6,  number: 6,  name: "Presence",
              blurb: "Body, voice, stillness.",            symbol: "figure.stand"),
        Track(id: 7,  number: 7,  name: "Deep Connection",
              blurb: "Vulnerability & depth.",             symbol: "heart.text.square.fill"),
        Track(id: 8,  number: 8,  name: "Confidence",
              blurb: "Calm under pressure.",               symbol: "flame.fill"),
        Track(id: 9,  number: 9,  name: "Personalization",
              blurb: "Your style, dialed in.",             symbol: "person.crop.circle.badge.checkmark"),
        Track(id: 10, number: 10, name: "Texting",
              blurb: "Pace, timing, words.",               symbol: "message.fill"),
        Track(id: 11, number: 11, name: "Dating App Strategy",
              blurb: "Profiles & matches.",                symbol: "rectangle.stack.person.crop.fill"),
        Track(id: 12, number: 12, name: "First-Date Logistics",
              blurb: "Plan, propose, show up.",            symbol: "calendar.badge.clock"),
        Track(id: 13, number: 13, name: "Dates → Relationship",
              blurb: "From third date to real.",           symbol: "heart.circle.fill")
    ]

    /// Canonical lecture counts per track 1...13.
    private static let counts: [Int: Int] = [
        0: 3, 1: 6, 2: 5, 3: 6, 4: 5, 5: 5, 6: 6,
        7: 6, 8: 6, 9: 5, 10: 7, 11: 5, 12: 6, 13: 6
    ]

    private static let lectureTitles: [Int: [String]] = [
        0: ["Welcome", "Where you are now", "Where you're going"],
        1: ["Why you, why now", "The non-needy mindset", "Self-worth basics",
            "Outcome independence", "Your dating identity", "Rejection isn't fatal"],
        2: ["The first 7 seconds", "Conversational openers",
            "Approaching with calm", "Body language entry", "Exits without sting"],
        3: ["The volley principle", "Following her thread", "Asking better questions",
            "Statements vs interrogations", "Silence as a tool", "The graceful close"],
        4: ["Playful, not performative", "Self-aware humor",
            "Callbacks & inside jokes", "Teasing without sting", "Reading laugh signals"],
        5: ["Verbal cues", "Pacing & energy match",
            "When she's polite vs interested", "Disinterest, gently named", "Recovery moves"],
        6: ["Voice fundamentals", "Stillness > fidget", "Eye contact rhythm",
            "Posture & openness", "Warmth in the face", "The slow exhale"],
        7: ["Mutual vulnerability", "The deeper question",
            "Listening louder", "Story instead of resume", "Holding space", "When she opens up"],
        8: ["Catching anxiety early", "Box breathing under fire", "Reframes that work",
            "Embracing nerves", "The 90-second wave", "Walking in calm"],
        9: ["Your flirting style", "The right kind of texts",
            "Coach mode that fits you", "Mistakes you keep making", "Your unfair advantage"],
        10: ["The opener that lands", "Pacing replies", "Memes, sparingly",
             "Asking her out via text", "Recovering ghost threads",
             "Voice notes, used well", "When to put down the phone"],
        11: ["Profile photo order", "The bio that filters", "Prompts that earn replies",
             "Swiping strategy", "Match → first message"],
        12: ["Choosing the spot", "The proposal text", "Day-of logistics",
             "Arriving grounded", "The first 60 seconds", "Closing the date well"],
        13: ["Third date energy", "Defining the thing",
             "Conflict, calmly", "Meeting her people", "Long game choices",
             "Becoming chosen"]
    ]

    static let lectures: [Lecture] = {
        var out: [Lecture] = []
        for (trackId, count) in counts {
            for i in 0..<count {
                let titles = lectureTitles[trackId] ?? []
                let title = i < titles.count ? titles[i] : "Lesson \(i + 1)"
                let weights: WeightProfile = trackId == 10 ? .texting : .standard
                out.append(Lecture(
                    id: "t\(trackId)-l\(i + 1)",
                    trackId: trackId,
                    number: i + 1,
                    title: title,
                    scenario: scenario(for: trackId, lesson: i + 1, title: title),
                    minutes: 4,
                    weights: weights
                ))
            }
        }
        return out.sorted { ($0.trackId, $0.number) < ($1.trackId, $1.number) }
    }()

    static func lectures(in trackId: Int) -> [Lecture] {
        lectures.filter { $0.trackId == trackId }
    }

    private static func scenario(for trackId: Int, lesson: Int, title: String) -> String {
        switch trackId {
        case 2: return "Mia is reading at a coffee shop. Approach warmly."
        case 3: return "You matched yesterday — keep the thread alive without trying too hard."
        case 5: return "She's polite but pulling back. Read it, name it kindly."
        case 10: return "Text exchange after a fun first date — keep the pace."
        case 12: return "First date logistics: propose Thursday, 7pm."
        default: return "Practice: \(title)."
        }
    }

    static let quizzes: [String: [QuizQuestion]] = {
        // Each lecture gets exactly 3 placeholder-but-meaningful Qs.
        var out: [String: [QuizQuestion]] = [:]
        for l in lectures {
            out[l.id] = [
                QuizQuestion(
                    prompt: "What's the core idea of '\(l.title)'?",
                    options: [
                        "Perform confidence so she believes it.",
                        "Stay grounded and curious about her, not the outcome.",
                        "Lead the conversation no matter what."
                    ],
                    correctIndex: 1
                ),
                QuizQuestion(
                    prompt: "She seems hesitant. The best next move is to…",
                    options: [
                        "Push harder so she warms up.",
                        "Lighten the energy and give her room.",
                        "Apologize and exit."
                    ],
                    correctIndex: 1
                ),
                QuizQuestion(
                    prompt: "A win in this lesson looks like…",
                    options: [
                        "She laughs once and gives you her number.",
                        "You leave the interaction more like yourself, not less.",
                        "You out-talk her by 2 to 1."
                    ],
                    correctIndex: 1
                )
            ]
        }
        return out
    }()
}
