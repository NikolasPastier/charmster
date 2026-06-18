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
    [
      hook, coreInsight,
      "Here's what good looks like. \(goodExample)",
      "And here's what to avoid. \(badExample)",
      practicalTakeaway, practiceHandoff,
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
        "Compliment her appearance",
      ],
      correctIndex: 1
    )
    let q2 = QuizQuestion(
      prompt: phrased("If your opener lands flat, what should you do?", coach: coach),
      options: [
        "Apologize and walk away",
        "Double down loudly",
        "Drop it and move to one real question",
        "Repeat it slower",
      ],
      correctIndex: 2
    )
    let q3 = QuizQuestion(
      prompt: phrased("Why does \(lecture.skill.lowercased()) work?", coach: coach),
      options: [
        "It signals presence without pressure",
        "It overwhelms her hesitation",
        "It locks her into the conversation",
        "It tests her interest level",
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
        return
          "You went \(result.sessionScore). Voice \(qual(result.voice)), face \(qual(result.face)). Slow the opener. Let her finish."
      }
      if gentle {
        return
          "Solid run — \(result.sessionScore). Voice was \(qual(result.voice)) and the face read \(qual(result.face)). When you're ready, try slowing the opener so she can land her thought first."
      }
      return
        "Straight up — you went \(result.sessionScore). The voice was \(qual(result.voice)), the face read \(qual(result.face)). Next rep: slow the opener and let her finish before you respond."
    case .scientist:
      if direct {
        return
          "Score \(result.sessionScore). Synchrony \(result.synchrony), lag ~\(latencyHint(result)). Replicate the calibration spike."
      }
      if gentle {
        return
          "You scored \(result.sessionScore). Synchrony \(result.synchrony) points to a small turn-taking lag (~\(latencyHint(result))). The moment your calibration jumped is the pattern worth gently leaning into next time."
      }
      return
        "Session score \(result.sessionScore). Synchrony \(result.synchrony) suggests turn-taking lag of roughly \(latencyHint(result)). Replicate the moment your calibration jumped — that's the pattern worth repeating."
    case .alphaMentor:
      if direct {
        return "\(result.sessionScore). Frame \(qual(result.face)). Don't chase. Own second three."
      }
      if gentle {
        return
          "Score: \(result.sessionScore). Your frame held \(qual(result.face)). No need to chase warmth — set the floor and give her room to step up. One small thing for the next rep: hold the silence at second three."
      }
      return
        "Score: \(result.sessionScore). Frame held \(qual(result.face)). Don't chase warmth — set the floor and let her step up. One thing for next rep: own the silence at second three."
    case .therapist:
      if direct {
        return
          "Comfort \(result.comfort). Score \(result.sessionScore). Drop your shoulders. One breath before answering."
      }
      if gentle {
        return
          "Really nice job showing up. Your comfort registered \(result.comfort) and your session was \(result.sessionScore). Notice the moments your shoulders dropped — that's your system telling you it felt safe. No pressure: try one slow breath before answering next time."
      }
      return
        "Nice job showing up. Comfort \(result.comfort), session \(result.sessionScore). Notice where your shoulders dropped — that's safety. Next time, try one slow breath before answering."
    case .wingman:
      if direct {
        return
          "\(result.sessionScore)/100. Voice \(qual(result.voice)), body \(qual(result.body)). One callback to the first 30 seconds."
      }
      if gentle {
        return
          "Mission run, \(result.sessionScore)/100 — that's a real run. Voice \(qual(result.voice)), body \(qual(result.body)). When you're ready: one callback to something she said in the first 30 seconds."
      }
      return
        "Mission run, \(result.sessionScore)/100. Voice \(qual(result.voice)), body \(qual(result.body)). Next mission: one callback to something she said in the first 30 seconds."
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
    let skill = lecture.skill
    switch coach {
    case .scientist:
      return CoachFrame(
        hook:
          "There's a clean mechanism behind \"\(title).\" Research on first-encounter dynamics shows the strongest warmth predictors aren't content — they're behavioral: timing, presence, and response pattern.",
        insight:
          "The mechanism behind \"\(title)\": \(scientistInsightBody(skill)) Run one rep with that as your single variable.",
        takeaway:
          "Concretely: shorten your first sentence, hold one beat longer than feels comfortable, and let your \(skill.lowercased()) signal do the work.",
        handoff:
          "Now we'll run it live — keep your first reply under five words, and notice how she lands the next beat."
      )
    case .alphaMentor:
      return CoachFrame(
        hook:
          "\(title) is a frame test. The room is asking who you are before you've said anything.",
        insight:
          "\(title) is about \(skill.lowercased()). Standards-first beats charm-first. You are not auditioning — you are deciding whether this moment is worth your attention, and your body should signal that before your mouth does.",
        takeaway:
          "One move: square your shoulders, drop your voice a quarter step, and shorten everything. \(skill.capitalized) isn't a technique — it's a posture.",
        handoff: "Run it. If she pushes, don't soften. Hold the line warmly."
      )
    case .therapist:
      return CoachFrame(
        hook: "\(title) is where most people armor up. Let's not do that.",
        insight:
          "In \"\(title)\", the work is \(skill.lowercased()). Your nervous system reads social risk faster than your brain reads the room. The skill isn't being fearless — it's noticing the spike, breathing through it, and staying warm.",
        takeaway:
          "Try one slow exhale before you speak. Name what's true about \(skill.lowercased()) in this moment. You don't have to be smooth — you have to be real.",
        handoff: "Let's practice. You're safe. The goal is showing up — not performing."
      )
    case .wingman:
      return CoachFrame(
        hook:
          "Mission brief: \(title). Your variable: \(skill.lowercased()) — no tricks, no scripts.",
        insight:
          "In \"\(title)\": \(skill.lowercased()) is your mission parameter. Open, hold a real exchange, and exit cleanly. Show up, run the play, and don't oversell.",
        takeaway:
          "Three rules for this rep: one true sentence, one real question applying \(skill.lowercased()), one clean exit.",
        handoff: "You're up. Run it like we drilled — I'm in your ear."
      )
    case .bigBrother:
      return CoachFrame(
        hook:
          "Real talk on \(title.lowercased()) — most guys overthink this and freeze. You're going to do the simple thing instead.",
        insight:
          "\"\(title)\" is about \(skill.lowercased()). The move isn't impressive. It's present. Lower the bar so far you can't fail: say one true thing, listen, respond to what she actually said.",
        takeaway:
          "Stop trying to be interesting. Apply \(skill.lowercased()) — be interested. That's the whole game today.",
        handoff: "Alright, get in there. I'll catch you on the other side."
      )
    }
  }

  /// One-sentence scientific summary for each curriculum skill, used in the
  /// Scientist coach's insight beat so content is unique per skill group.
  private func scientistInsightBody(_ skill: String) -> String {
    switch skill {
    case "Opening":
      return "opening compresses voice, eye contact, and turn-taking into one moment. Two of three signals land the warmth — aim for that ratio, not perfection."
    case "Presence":
      return "presence is a proximity signal. Eye contact at natural intervals — not sustained, not avoidant — reads as chosen calm, not nervous scanning."
    case "Flow":
      return "turn-taking latency under 1.5 seconds signals engagement. A callback across a conversational gap proves you held the thread — that's the warmth predictor."
    case "Confidence":
      return "confidence is behavioral: shorter sentences, slower tempo, fewer qualifiers. Not a personality trait — a set of adjustable outputs."
    case "Banter":
      return "light back-and-forth increases perceived playfulness, which correlates with openness scores in attraction research. The signal is ease — not volume or cleverness."
    case "Calibration":
      return "affect-matching works at 70%, not 100%. Partial matching reads as understanding; full matching reads as mimicry. Meet her halfway and hold there."
    case "Connection":
      return "emotional disclosure follows a reciprocity curve. The first person to go slightly deeper sets the ceiling for the interaction — that's the lever you control."
    case "Texting":
      return "response time and message length are the two observable variables in texting dynamics. Restraint on both predicts sustained engagement better than volume."
    case "Dates":
      return "a specific plan removes ambiguity — a documented friction source in early-stage attraction. Decision fatigue on her side drops; confidence signal on yours rises."
    case "Style":
      return "first impressions form in under 250 milliseconds and prove highly stable. External coherence (style, grooming) signals identity before a word is spoken."
    case "Attachment":
      return "consistent behavioral rate — independent of her pace variation — reduces anxiety for both parties. Matching her distance fluctuations reinforces the anxious loop."
    case "EQ":
      return "affect labeling (naming what's happening emotionally) reduces amygdala response. Being heard lowers arousal; being advised raises it. Know the difference."
    case "Context":
      return "environmental priming affects emotional set points before the social interaction begins. The venue is a variable — choose it with the same care as your opener."
    case "Apps":
      return "response rate on apps follows a power-law distribution. Top openers reference specific rather than generic information. Signal-to-noise matters more than volume."
    case "Relationship":
      return "a stable behavioral rate — independent of her pace variation — is the most reliable long-term predictor of trust. Don't calibrate your rate to her anxiety."
    case "Foundations":
      return "attraction is modular: multiple independent mechanisms contribute in parallel. Understanding the architecture lets you target the right lever instead of optimizing the wrong one."
    default:
      return "the core skill compresses three signals. When any two align, the third follows. Pick the two you can most directly influence and let the third emerge."
    }
  }

  // MARK: - Examples

  private func goodExample(for lecture: Lecture) -> String {
    switch lecture.skill {
    case "Opening":
      return
        "You: 'That book looks better than mine.' She glances up, half-smiles. You wait a beat. She says, 'It is, actually.' You: 'Sell me.'"
    case "Presence":
      return
        "Three seconds of eye contact, soft smile, then look away — not down. The pause feels chosen, not nervous."
    case "Flow":
      return
        "Earlier she joked about her terrible coffee. Eight minutes later: 'On a scale from your coffee to good — how was your day?'"
    case "Confidence":
      return
        "She asks why you're so calm. You don't explain. You smile: 'I like myself — it's a recent development.' She laughs. You move on."
    case "Banter":
      return
        "She says, 'You're probably like this with everyone.' You: 'Only the interesting ones.' Short, light, no explanation needed."
    case "Calibration":
      return
        "She's animated; you match halfway. She adjusts to meet you. The conversation finds its level. She stops performing."
    case "Connection":
      return
        "She mentions something she's afraid of. You don't fix it. You say: 'Yeah, that's real.' She exhales and says three more sentences."
    case "Texting":
      return
        "She says 'maybe.' You wait 12 hours and reply with one specific observation. She responds in four minutes."
    case "Dates":
      return
        "You name a place, time, and one backup. 'Saturday at The Standard, 7:30. If that's wrong, there's a wine bar two blocks away.' She says yes."
    case "Style":
      return
        "She notices the detail before you mention it. It opens the conversation on your terms — no explaining required."
    case "Attachment":
      return
        "She pulls back. You give space without disappearing. She comes back more open than before."
    case "EQ":
      return
        "She's off. You don't push. 'You don't have to be on today.' She exhales and actually shows up."
    case "Context":
      return
        "You choose a spot that already tells half the story: comfortable, specific, easy to extend. She walks in already at ease."
    case "Apps":
      return
        "Your opener references one specific thing from her profile — not a compliment, just an observation. She gets twenty messages. She replies to yours."
    case "Relationship":
      return
        "She tests the pace. You don't rush to reassure. You hold your rate. She trusts the speed more for it."
    case "Foundations":
      return
        "You show up curious, not to perform. She mentions something offhand; you ask the one question that would actually interest you. The conversation has weight."
    default:
      return
        "You stay on the beat she set, respond once, ask one real question, and leave space for her to land it."
    }
  }

  private func badExample(for lecture: Lecture) -> String {
    switch lecture.skill {
    case "Opening":
      return
        "You: 'Hey so what do you do?' She gives a one-word answer. You fill the silence with three more questions in a row."
    case "Presence":
      return "Quick glance, then phone, then glance again. The energy reads anxious, not warm."
    case "Flow":
      return "You ignore the callback and pivot to a rehearsed story about your weekend."
    case "Confidence":
      return
        "She asks why you're confident. You list reasons. Now you're auditioning instead of living it."
    case "Banter":
      return
        "She teases; you take it seriously and explain yourself. The energy deflates — now you're having a different conversation."
    case "Calibration":
      return
        "She's low-energy; you turn it up to compensate. Now the gap is wider. She retreats further."
    case "Connection":
      return
        "She shares something real. You match with a story about yourself. She stops sharing."
    case "Texting":
      return
        "She replies slowly, so you send three follow-ups in ninety minutes. She goes quiet."
    case "Dates":
      return
        "'What do you want to do?' She says, 'I don't know.' You say, 'Me neither.' Nothing happens."
    case "Style":
      return
        "You over-explain your outfit choice before she has a chance to notice it. Now it's a presentation, not a statement."
    case "Attachment":
      return "She needs space; you press for reassurance. She pulls further back. You press more."
    case "EQ":
      return
        "She's having a rough day. You try to fix it immediately. She closes down — she wanted to be heard, not solved."
    case "Context":
      return
        "You pick a loud, crowded bar because it seems impressive. She can't hear you. The date drains instead of builds."
    case "Apps":
      return
        "You open with 'Hey, how's your day?' She has eighty of those. Yours looks exactly like the rest."
    case "Relationship":
      return
        "You push the pace because you're excited. She feels pressure instead of pull. She slows down to compensate."
    case "Foundations":
      return
        "You focus on saying the right thing instead of being present. She can feel the gap. The conversation is technically fine but somehow hollow."
    default:
      return
        "You match her energy with a bigger version of it. Now you're performing, not connecting."
    }
  }

  // MARK: - Helpers

  private func phrased(_ base: String, coach: CoachStyle) -> String {
    switch coach {
    case .scientist: return "[Mechanism] \(base)"
    case .alphaMentor: return "[Frame] \(base)"
    case .therapist: return "Gently — \(base)"
    case .wingman: return "Mission check: \(base)"
    case .bigBrother: return "Real talk — \(base)"
    }
  }

  private func qual(_ v: Int) -> String {
    switch v {
    case 85...: return "dialed"
    case 70..<85: return "solid"
    case 55..<70: return "wobbly"
    default: return "off"
    }
  }

  private func latencyHint(_ r: SessionResult) -> String {
    r.synchrony > 75 ? "well under a second" : "1.5 seconds or more"
  }
}
