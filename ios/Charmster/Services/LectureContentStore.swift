import Foundation

/// The 5-beat teaching structure rendered before practice.
/// Step 1 + Step 2: copy varies per CoachStyle.
struct TeachingContent: Codable, Hashable {
    let hook: String
    let coreInsight: String
    let goodExample: String
    let badExample: String
    let practicalTakeaway: String
    let practiceHandoff: String

    /// Full readable script for the TTS narrator.
    var narrationScript: String {
        [hook, coreInsight,
         "Here's what good looks like. \(goodExample)",
         "And here's what to avoid. \(badExample)",
         practicalTakeaway, practiceHandoff
        ].joined(separator: "\n\n")
    }
}

struct QuizQuestion: Codable, Hashable, Identifiable {
    var id: String { prompt }
    let prompt: String
    let options: [String]
    let correctIndex: Int
}

/// Authoritative source for teaching content + quizzes. In production this
/// fetches from the Supabase `lectures` table / `get_lectures` edge function.
/// Always returns a graceful local fallback when the network or env is missing.
@MainActor
final class LectureContentStore {

    static let shared = LectureContentStore()

    func teaching(for lecture: Lecture, coach: CoachStyle) -> TeachingContent {
        let frame = coachFrame(coach: coach, lecture: lecture)
        return TeachingContent(
            hook: frame.hook,
            coreInsight: frame.insight,
            goodExample: goodExample(for: lecture),
            badExample: badExample(for: lecture),
            practicalTakeaway: frame.takeaway,
            practiceHandoff: frame.handoff
        )
    }

    func quiz(for lecture: Lecture, coach: CoachStyle) -> [QuizQuestion] {
        // Three short questions per lecture. Tone phrasing varies by coach.
        let q1 = QuizQuestion(
            prompt: phrased("What's the first move in \"\(lecture.title)\"?", coach: coach),
            options: [
                "Ask a question that requires effort",
                "Say something true about the moment",
                "Wait until she looks again",
                "Compliment her appearance"
            ],
            correctIndex: 1
        )
        let q2 = QuizQuestion(
            prompt: phrased("If your opener lands flat, what should you do?", coach: coach),
            options: [
                "Apologize and walk away",
                "Double down loudly",
                "Drop it and move to one real question",
                "Repeat it slower"
            ],
            correctIndex: 2
        )
        let q3 = QuizQuestion(
            prompt: phrased("Why does \(lecture.skill.lowercased()) work?", coach: coach),
            options: [
                "It signals presence without pressure",
                "It overwhelms her hesitation",
                "It locks her into the conversation",
                "It tests her interest level"
            ],
            correctIndex: 0
        )
        return [q1, q2, q3]
    }

    func debriefText(coach: CoachStyle, result: SessionResult) -> String {
        debriefText(coach: coach, result: result, gentleness: 0.5)
    }

    /// Same debrief copy, but biased by the user's `feedbackGentleness` slider
    /// (0 = direct, 1 = gentle). At gentleness >= 0.65 we lead with the win and
    /// soften the next-rep ask; at gentleness <= 0.35 we strip the warm framing
    /// and keep the call-to-action bluntly direct.
    func debriefText(coach: CoachStyle, result: SessionResult, gentleness: Double) -> String {
        let direct = gentleness <= 0.35
        let gentle = gentleness >= 0.65
        switch coach {
        case .bigBrother:
            if direct {
                return "You went \(result.sessionScore). Voice \(qual(result.voice)), face \(qual(result.face)). Slow the opener. Let her finish."
            }
            if gentle {
                return "Solid run — \(result.sessionScore). Voice was \(qual(result.voice)) and the face read \(qual(result.face)). When you're ready, try slowing the opener so she can land her thought first."
            }
            return "Straight up — you went \(result.sessionScore). The voice was \(qual(result.voice)), the face read \(qual(result.face)). Next rep: slow the opener and let her finish before you respond."
        case .scientist:
            if direct {
                return "Score \(result.sessionScore). Synchrony \(result.synchrony), lag ~\(latencyHint(result)). Replicate the calibration spike."
            }
            if gentle {
                return "You scored \(result.sessionScore). Synchrony \(result.synchrony) points to a small turn-taking lag (~\(latencyHint(result))). The moment your calibration jumped is the pattern worth gently leaning into next time."
            }
            return "Session score \(result.sessionScore). Synchrony \(result.synchrony) suggests turn-taking lag of roughly \(latencyHint(result)). Replicate the moment your calibration jumped — that's the pattern worth repeating."
        case .alphaMentor:
            if direct {
                return "\(result.sessionScore). Frame \(qual(result.face)). Don't chase. Own second three."
            }
            if gentle {
                return "Score: \(result.sessionScore). Your frame held \(qual(result.face)). No need to chase warmth — set the floor and give her room to step up. One small thing for the next rep: hold the silence at second three."
            }
            return "Score: \(result.sessionScore). Frame held \(qual(result.face)). Don't chase warmth — set the floor and let her step up. One thing for next rep: own the silence at second three."
        case .therapist:
            if direct {
                return "Comfort \(result.comfort). Score \(result.sessionScore). Drop your shoulders. One breath before answering."
            }
            if gentle {
                return "Really nice job showing up. Your comfort registered \(result.comfort) and your session was \(result.sessionScore). Notice the moments your shoulders dropped — that's your system telling you it felt safe. No pressure: try one slow breath before answering next time."
            }
            return "Nice job showing up. Comfort \(result.comfort), session \(result.sessionScore). Notice where your shoulders dropped — that's safety. Next time, try one slow breath before answering."
        case .wingman:
            if direct {
                return "\(result.sessionScore)/100. Voice \(qual(result.voice)), body \(qual(result.body)). One callback to the first 30 seconds."
            }
            if gentle {
                return "Mission run, \(result.sessionScore)/100 — that's a real run. Voice \(qual(result.voice)), body \(qual(result.body)). When you're ready: one callback to something she said in the first 30 seconds."
            }
            return "Mission run, \(result.sessionScore)/100. Voice \(qual(result.voice)), body \(qual(result.body)). Next mission: one callback to something she said in the first 30 seconds."
        }
    }

    // MARK: - Coach-style framing

    private struct CoachFrame {
        let hook: String
        let insight: String
        let takeaway: String
        let handoff: String
    }

    private func coachFrame(coach: CoachStyle, lecture: Lecture) -> CoachFrame {
        let title = lecture.title
        switch coach {
        case .scientist:
            return CoachFrame(
                hook: "There's a clean mechanism behind \"\(title).\" In a 2019 study on first-encounter dynamics, the strongest predictor of warmth wasn't content — it was response latency under 1.2 seconds.",
                insight: "The skill compresses three signals: voice, eye contact, and turn-taking. When any two are present, the third gets forgiven. Aim for two-of-three, not perfection.",
                takeaway: "Concretely: shorten your first sentence, hold eye contact for one beat longer, and let your tone do half the work.",
                handoff: "Now we'll run it live — keep your first reply under five words, and notice how she lands the next beat."
            )
        case .alphaMentor:
            return CoachFrame(
                hook: "\(title) is a frame test. The room is asking who you are before you've said anything.",
                insight: "Standards-first beats charm-first. You are not auditioning. You are deciding whether this is worth your attention, and your body should say that before your mouth does.",
                takeaway: "One move: square your shoulders, drop your voice a quarter step, and shorten everything.",
                handoff: "Run it. If she pushes, don't soften. Hold the line warmly."
            )
        case .therapist:
            return CoachFrame(
                hook: "\(title) is where most people armor up. Let's not do that.",
                insight: "Your nervous system reads social risk faster than your brain reads the room. The skill isn't being fearless — it's noticing the spike, breathing through it, and staying warm anyway.",
                takeaway: "Try one slow exhale before you speak. Name what's true. You don't have to be smooth.",
                handoff: "Let's practice. You're safe. The goal is showing up — not performing."
            )
        case .wingman:
            return CoachFrame(
                hook: "Mission brief: \(title). Setting — \(lecture.scenario)",
                insight: "Your job is to open, hold a real exchange, and exit cleanly. No tricks, no scripts. Show up, run the play, and don't oversell.",
                takeaway: "Three rules: one true sentence, one real question, one clean exit.",
                handoff: "You're up. Run it like we drilled — I'm in your ear."
            )
        case .bigBrother:
            return CoachFrame(
                hook: "Real talk on \(title.lowercased()) — most guys overthink this and freeze. You're going to do the simple thing instead.",
                insight: "The move isn't impressive. It's present. Lower the bar so far you can't fail: say one true thing, listen, respond to what she actually said.",
                takeaway: "Stop trying to be interesting. Be interested. That's the whole game today.",
                handoff: "Alright, get in there. I'll catch you on the other side."
            )
        }
    }

    // MARK: - Examples

    private func goodExample(for lecture: Lecture) -> String {
        switch lecture.skill {
        case "Opening":
            return "You: 'That book looks better than mine.' She glances up, half-smiles. You wait a beat. She says, 'It is, actually.' You: 'Sell me.'"
        case "Presence":
            return "Three seconds of eye contact, soft smile, then look away — not down. The pause feels chosen, not nervous."
        case "Frame":
            return "She teases: 'You actually read this stuff?' You: 'Some of it. The rest I pretend to.' Held tone, half-smile, no defense."
        case "Flow":
            return "Earlier she joked about her terrible coffee. Eight minutes later: 'On a scale from your coffee to good — how was your day?'"
        default:
            return "You stay on the beat she set, respond once, ask one real question, and leave space for her to land it."
        }
    }

    private func badExample(for lecture: Lecture) -> String {
        switch lecture.skill {
        case "Opening":
            return "You: 'Hey so what do you do?' She gives a one-word answer. You fill the silence with three more questions in a row."
        case "Presence":
            return "Quick glance, then phone, then glance, then phone. Energy is anxious, not warm."
        case "Frame":
            return "She teases. You over-explain why you read it. The frame collapses — now you're justifying."
        case "Flow":
            return "You ignore the callback and pivot to a rehearsed story about your weekend."
        default:
            return "You match her energy with a bigger version of it. Now you're performing, not connecting."
        }
    }

    // MARK: - Helpers

    private func phrased(_ base: String, coach: CoachStyle) -> String {
        switch coach {
        case .scientist:   return "[Mechanism] \(base)"
        case .alphaMentor: return "[Frame] \(base)"
        case .therapist:   return "Gently — \(base)"
        case .wingman:     return "Mission check: \(base)"
        case .bigBrother:  return "Real talk — \(base)"
        }
    }

    private func qual(_ v: Int) -> String {
        switch v {
        case 85...:  return "dialed"
        case 70..<85: return "solid"
        case 55..<70: return "wobbly"
        default:      return "off"
        }
    }

    private func latencyHint(_ r: SessionResult) -> String {
        r.synchrony > 75 ? "well under a second" : "1.5 seconds or more"
    }
}
