import Foundation

/// Charmster feedback engine. Applies the playbook formulas:
/// 6 dimensions → weighted rawScore → 4 feel meters → feelScore → sessionScore.
/// SAFETY GATE: if Comfort < 50, sessionScore is capped at 65.
enum SessionScorer {
    /// Generates a deterministic mocked session result for a lecture.
    /// In production these dimensions come from transcript + audio + vision signals.
    static func score(for lecture: Lecture,
                      tier: DifficultyTier,
                      seed: UInt64? = nil) -> SessionResult {
        var rng = SystemRandomNumberGenerator()
        let s = seed ?? UInt64.random(in: 0..<UInt64.max, using: &rng)
        var gen = SplitMix64(state: s)

        // Dimension scores 0-100 — biased above midpoint, varied by tier.
        let bias: Int = {
            switch tier {
            case .bronze: return 18
            case .silver: return 10
            case .gold:   return 0
            }
        }()
        func dim(_ low: Int, _ high: Int) -> Int {
            let raw = Int(gen.nextDouble() * Double(high - low)) + low + bias
            return max(0, min(100, raw))
        }

        let responsiveness = dim(45, 92)
        let voice          = dim(45, 90)
        let face           = dim(50, 92)
        let body           = dim(40, 88)
        let synchrony      = dim(45, 90)
        let calibration    = dim(40, 88)

        let w = lecture.weights
        let weightedSum =
            Double(responsiveness) * w.responsiveness +
            Double(voice)          * w.voice +
            Double(face)           * w.face +
            Double(body)           * w.body +
            Double(synchrony)      * w.synchrony +
            Double(calibration)    * w.calibration
        let totalWeight = w.responsiveness + w.voice + w.face + w.body + w.synchrony + w.calibration
        let rawScore = Int(round(weightedSum / max(0.01, totalWeight)))

        // Feel meters derived from the dimensions.
        let comfort = clamp((face + voice + calibration) / 3 - 4)
        let interest = clamp((responsiveness + synchrony + voice) / 3)
        let spark = clamp((synchrony + face + calibration) / 3 - 2)
        let respect = clamp((calibration + comfort) / 2)

        let feelScore =
            0.30 * Double(comfort) +
            0.25 * Double(interest) +
            0.30 * Double(spark) +
            0.15 * Double(respect)

        var session = Int(round(0.5 * Double(rawScore) + 0.5 * feelScore))

        // SAFETY GATE
        if comfort < 50 { session = min(session, 65) }

        // Rewards
        let xp = sessionXP(aiRating: session, tier: tier)
        let coins = bonusCoins(session)

        return SessionResult(
            responsiveness: responsiveness, voice: voice, face: face, body: body,
            synchrony: synchrony, calibration: calibration,
            comfort: comfort, interest: interest, spark: spark, respect: respect,
            sessionScore: session,
            reaction: reaction(comfort: comfort, interest: interest, spark: spark, respect: respect),
            strengths: strengths(face: face, voice: voice, calibration: calibration, responsiveness: responsiveness),
            fixes: fixes(comfort: comfort, interest: interest, spark: spark,
                         body: body, voice: voice, synchrony: synchrony),
            xpEarned: xp,
            coinsEarned: coins
        )
    }

    /// sessionXP = round((20 + 40 * (aiRating/100)) * tierMultiplier) — Daily Double handled by caller.
    static func sessionXP(aiRating: Int, tier: DifficultyTier, dailyDouble: Bool = false) -> Int {
        let base = (20.0 + 40.0 * Double(aiRating) / 100.0) * tier.multiplier
        let mult: Double = dailyDouble ? 2 : 1
        return Int(round(base * mult))
    }

    private static func bonusCoins(_ session: Int) -> Int {
        switch session {
        case 90...: return 15
        case 75...: return 10
        case 60...: return 5
        default:    return 0
        }
    }

    private static func clamp(_ x: Int) -> Int { max(0, min(100, x)) }

    private static func reaction(comfort: Int, interest: Int, spark: Int, respect: Int) -> String {
        let avg = (comfort + interest + spark + respect) / 4
        switch avg {
        case 90...: return "\"I don't usually feel this comfortable this fast — I really enjoyed that.\""
        case 75...: return "\"That was actually really nice. I'd want to keep talking.\""
        case 60...: return "\"It was good. I felt like you were actually listening.\""
        case 40...: return "\"You seem kind. I'm not sure I felt a spark yet.\""
        default:    return "\"I think the timing's off for me right now.\""
        }
    }

    private static func strengths(face: Int, voice: Int, calibration: Int, responsiveness: Int) -> [String] {
        var out: [String] = []
        if responsiveness >= 70 { out.append("You built on what she said instead of waiting to talk.") }
        if face >= 70 { out.append("Your warmth landed — your face matched your words.") }
        if voice >= 70 { out.append("Your pacing was easy to follow and felt grounded.") }
        if calibration >= 70 { out.append("You read her cues and adjusted in real time.") }
        if out.isEmpty { out = ["You stayed in the conversation, even when it got quiet."] }
        return Array(out.prefix(2))
    }

    private static func fixes(comfort: Int, interest: Int, spark: Int,
                              body: Int, voice: Int, synchrony: Int) -> [String] {
        var out: [String] = []
        if comfort < 60 { out.append("Slow the first 30 seconds — let her see your face settle before you ask.") }
        if interest < 60 { out.append("Trade one fact-question for a curious follow-up about *why* she said that.") }
        if spark < 60 { out.append("Add one playful callback — repeat a phrase she used, with a smile.") }
        if synchrony < 60 { out.append("Match her energy floor first; raise it from there in small steps.") }
        if voice < 60 { out.append("Drop your voice a notch on key lines — calm reads as confidence.") }
        if body < 60 { out.append("Open posture and one slow exhale before you reply.") }
        if out.isEmpty { out = ["Try the same scenario at Silver tier — push your range a notch."] }
        return Array(out.prefix(3))
    }
}

/// Deterministic small RNG for repeatable mocks.
private struct SplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
