import Foundation

/// Derives the ordered 5-beat `LectureStory` from the EXISTING coach-styled
/// teaching content + quiz. This is a DELIVERY transform, not a curriculum
/// rewrite: it reuses `LectureContentStore` (single source of truth for copy)
/// and `CoachPersona` voice/persona, then layers per-beat visual + signal
/// metadata and infers `conversationMode`.
@MainActor
enum LectureStoryBuilder {

  static func build(for lecture: Lecture, coach: CoachPersona) -> LectureStory {
    let content = LectureContentStore.shared.teaching(for: lecture, coach: coach.style)
    let mode = conversationMode(for: lecture)

    let plc = PerLectureContentStore.shared.content(for: lecture.id)
    let capContent = CapstoneContentStore.shared.content(for: lecture)

    // Objectives: per-lecture content takes priority; skill template is fallback.
    let objectives: [String]
    if let authored = plc?.objectives {
      objectives = authored
    } else {
      objectives = learningObjectives(for: lecture, content: content, mode: mode)
    }

    // Good vs Bad: per-lecture content takes priority; skill template is fallback.
    let goodEx: ContrastExample
    let badEx: ContrastExample
    if let gvb = plc?.goodVsBad {
      let inPersonTag = mode == .inPerson
      goodEx = ContrastExample(line: gvb.works, reactionTag: inPersonTag ? gvb.leansIn : nil)
      badEx = ContrastExample(line: gvb.avoid, reactionTag: inPersonTag ? gvb.checksOut : nil)
    } else {
      goodEx = example(from: content.goodExample, mode: mode, isGood: true)
      badEx = example(from: content.badExample, mode: mode, isGood: false)
    }

    // Recall: per-lecture content takes priority; quiz template is fallback.
    let recall: RecallCheck
    if let rc = plc?.recall {
      recall = RecallCheck(
        question: rc.question,
        options: Array(rc.options.prefix(4)),
        correctIndex: min(rc.answerIndex, max(0, rc.options.count - 1)),
        why: rc.explanation
      )
    } else {
      recall = recallCheck(for: lecture, coach: coach.style)
    }

    let beats: [LectureBeat] = [
      // 1 — HOOK (avatar speaks, emotional)
      LectureBeat(
        id: "\(lecture.id).hook",
        kind: .hook,
        narrationText: content.hook,
        signalPhrase: hookSignal(for: lecture),
        visual: .avatar,
        keyPoints: hookKeyPoints(for: lecture)
      ),
      // 2 — CORE INSIGHT (voiceover + emphasis visual)
      LectureBeat(
        id: "\(lecture.id).insight",
        kind: .coreInsight,
        narrationText: content.coreInsight,
        signalPhrase: insightSignal(for: lecture),
        visual: .contrastCards,
        keyPoints: insightKeyPoints(for: lecture)
      ),
      // 3 — GOOD vs BAD (mode-driven visual) — no key points: cards ARE the content
      LectureBeat(
        id: "\(lecture.id).goodbad",
        kind: .goodVsBad,
        narrationText: goodVsBadNarration(content: content, mode: mode),
        signalPhrase: mode == .texting ? "What you send back" : "What you say out loud",
        visual: mode == .texting ? .chatMockup : .spokenLineCards,
        goodExample: goodEx,
        badExample: badEx
      ),
      // 4 — RECALL CHECK — no key points: question IS the content
      LectureBeat(
        id: "\(lecture.id).recall",
        kind: .recallCheck,
        narrationText: "Quick gut-check before you practice — \(recall.question)",
        signalPhrase: "Your call",
        visual: .recallQuestion,
        recall: recall
      ),
      // 5 — TAKEAWAY + HANDOFF (avatar speaks, energizing)
      LectureBeat(
        id: "\(lecture.id).takeaway",
        kind: .takeawayHandoff,
        narrationText: capContent?.coachIntro ?? "\(content.practicalTakeaway) \(content.practiceHandoff)",
        signalPhrase: takeawaySignal(for: lecture),
        visual: .avatar,
        keyPoints: takeawayKeyPoints(for: lecture)
      ),
    ]

    return LectureStory(
      lectureId: lecture.id, coachId: coach.id, conversationMode: mode, beats: beats,
      learningObjectives: objectives)
  }

  // MARK: - Learning objectives (UX5 — Card 0 "What you'll learn")

  /// 2–3 outcome lines previewed on the intro card. DERIVED from existing
  /// lecture metadata + already-built teaching content — never a rewrite.
  ///   • obj1: the skill/concept as a capability ("You'll be able to ____")
  ///   • obj2: one behavior outcome ("Say/Do ____")
  ///   • obj3 (optional): "Avoid ____" — only when the lecture already carries
  ///     a bad-example signal to anchor it.
  static func learningObjectives(
    for lecture: Lecture, content: TeachingContent, mode: ConversationMode
  ) -> [String] {
    var out: [String] = []
    out.append(capabilityObjective(for: lecture))
    out.append(behaviorObjective(for: lecture, mode: mode))
    if let avoid = avoidObjective(for: lecture, content: content) {
      out.append(avoid)
    }
    return Array(out.prefix(3))
  }

  private static func capabilityObjective(for lecture: Lecture) -> String {
    switch lecture.skill {
    case "Opening": return "Open with one true line that earns a real reply"
    case "Presence": return "Stay present instead of performing"
    case "Flow": return "Keep a conversation moving with callbacks"
    case "Confidence": return "Project calm self-assurance without broadcasting it"
    case "Banter": return "Hold light back-and-forth without collapsing into seriousness"
    case "Calibration": return "Read her energy and meet it at the right level"
    case "Connection": return "Create a moment where she actually opens up"
    case "Texting": return "Write messages that invite a real reply, not just a read receipt"
    case "Dates": return "Plan and lead a date without seeking approval"
    case "Style": return "Let your presentation do quiet work before you speak"
    case "Attachment": return "Respond to push-and-pull without chasing or disappearing"
    case "EQ": return "Read the emotional room and respond, not react"
    case "Context": return "Choose environments that do half the work for you"
    case "Apps": return "Stand out with a message that's actually about her"
    case "Relationship": return "Hold a healthy pace when both of you are invested"
    case "Foundations": return "Understand why attraction works before you optimize for it"
    default: return "Handle \(lecture.skill.lowercased()) with calm intent"
    }
  }

  private static func behaviorObjective(for lecture: Lecture, mode: ConversationMode) -> String {
    switch lecture.skill {
    case "Opening":
      return mode == .texting
        ? "Send a first message that invites a reply" : "Say a clean, specific opener out loud"
    case "Presence": return "Notice, breathe, and hold the moment"
    case "Flow": return "Use one callback to show you listened"
    case "Confidence": return "Hold a pause without filling it"
    case "Banter": return "Return one light tease without over-explaining"
    case "Calibration": return "Read her energy and respond one step inside it"
    case "Connection": return "Ask one real question and actually wait for the answer"
    case "Texting": return "Reply with intent, not reflex"
    case "Dates": return "Name a plan without asking for approval"
    case "Style": return "Let the detail create the opening for you"
    case "Attachment": return "Give space on purpose and see what comes back"
    case "EQ": return "Name what's happening without making it bigger"
    case "Context": return "Choose the setting before choosing the opener"
    case "Apps": return "Write one message that references something specific in her profile"
    case "Relationship": return "Hold your pace when she changes hers"
    case "Foundations":
      return mode == .texting
        ? "Apply one principle deliberately, once" : "Identify the mechanism in a real moment"
    default: return mode == .texting ? "Reply with intent, not filler" : "Say it with steady tone"
    }
  }

  /// Only surfaced when the lecture already has a usable bad-example signal —
  /// so the "Avoid" line is grounded in existing content, not invented.
  private static func avoidObjective(for lecture: Lecture, content: TeachingContent) -> String? {
    let bad = content.badExample.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !bad.isEmpty else { return nil }
    switch lecture.skill {
    case "Opening": return "Avoid the survey-style question opener"
    case "Presence": return "Avoid the nervous, over-eager read"
    case "Flow": return "Avoid one-word, momentum-killing replies"
    case "Confidence": return "Avoid explaining yourself when silence would do"
    case "Banter": return "Avoid taking a tease seriously and deflating the energy"
    case "Calibration": return "Avoid matching her energy all the way up or down"
    case "Connection": return "Avoid pivoting to yourself before she's finished"
    case "Texting": return "Avoid triple-texting when she hasn't replied"
    case "Dates": return "Avoid asking 'what do you want to do?' and leaving it open"
    case "Style": return "Avoid over-explaining your choices before she notices"
    case "Attachment": return "Avoid chasing reassurance when she pulls back"
    case "EQ": return "Avoid rushing to fix what she just needs to feel"
    case "Context": return "Avoid noisy venues that work against connection"
    case "Apps": return "Avoid the generic opener that looks like everyone else's"
    case "Relationship": return "Avoid accelerating the pace when she slows down"
    case "Foundations": return "Avoid performing attractiveness instead of embodying it"
    default: return "Avoid the move that makes her check out"
    }
  }

  // MARK: - Conversation mode inference

  /// DEFAULT inPerson. A lecture is `texting` ONLY when it's explicitly about
  /// texting/messaging — inferred from skill + title/scenario keywords. Stored
  /// on the story so it stays editable.
  static func conversationMode(for lecture: Lecture) -> ConversationMode {
    if lecture.skill.localizedCaseInsensitiveContains("Texting") { return .texting }
    let haystack = "\(lecture.title) \(lecture.scenario)".lowercased()
    let textingHints = [
      "text", "texting", "message", "messaging", "reply", "replies", "chat",
      "dm", "send back", "talking stage", "voice note",
    ]
    if textingHints.contains(where: { haystack.contains($0) }) { return .texting }
    return .inPerson
  }

  // MARK: - Good vs Bad examples

  private static func goodVsBadNarration(content: TeachingContent, mode: ConversationMode)
    -> String
  {
    let lead =
      mode == .texting
      ? "Here's the message that lands — and the one that kills it."
      : "Here's how it sounds when it works — and when it doesn't."
    return "\(lead) \(content.goodExample) Versus: \(content.badExample)"
  }

  private static func example(from raw: String, mode: ConversationMode, isGood: Bool)
    -> ContrastExample
  {
    let line = condense(raw)
    let tag = mode == .inPerson ? reactionTag(isGood: isGood) : nil
    return ContrastExample(line: line, reactionTag: tag)
  }

  /// Trim the long teaching prose into a tight quotable line for the card.
  private static func condense(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count <= 160 { return trimmed }
    // Keep through the second sentence boundary, else hard cap.
    let parts = trimmed.split(separator: ".", omittingEmptySubsequences: true)
    if parts.count >= 2 {
      return parts.prefix(2).joined(separator: ".").trimmingCharacters(in: .whitespaces) + "."
    }
    return String(trimmed.prefix(157)) + "…"
  }

  private static func reactionTag(isGood: Bool) -> String {
    isGood ? "She leans in" : "She checks out"
  }

  // MARK: - Recall (one quick question, reuse quiz bank)

  static func recallCheck(for lecture: Lecture, coach: CoachStyle) -> RecallCheck {
    let q = LectureContentStore.shared.quiz(for: lecture, coach: coach).first
    guard let q else {
      return RecallCheck(
        question: "What's the move today?",
        options: ["Be present", "Be impressive"],
        correctIndex: 0,
        why: "Presence beats performance — that's the whole skill.")
    }
    // Keep to 3 options max for a light, single-tap beat.
    let trimmedOptions = Array(q.options.prefix(3))
    let safeCorrect = min(q.correctIndex, trimmedOptions.count - 1)
    return RecallCheck(
      question: cleanPrompt(q.prompt),
      options: trimmedOptions,
      correctIndex: safeCorrect,
      why: recallWhy(for: lecture))
  }

  private static func cleanPrompt(_ prompt: String) -> String {
    // Strip the coach tone prefix the quiz adds (e.g. "[Frame] …", "Real talk — …").
    if let range = prompt.range(of: "] ") { return String(prompt[range.upperBound...]) }
    if let range = prompt.range(of: "— ") { return String(prompt[range.upperBound...]) }
    if let range = prompt.range(of: ": ") { return String(prompt[range.upperBound...]) }
    return prompt
  }

  private static func recallWhy(for lecture: Lecture) -> String {
    switch lecture.skill {
    case "Opening": return "One true thing invites a real reply — questions feel like a survey."
    case "Presence": return "A chosen pause reads as calm; a nervous glance reads as anxious."
    case "Flow": return "A callback proves you listened — that's what makes her stay."
    case "Confidence": return "Confidence isn't loudness — it's the willingness to take up space quietly."
    case "Banter": return "Light teasing signals ease; over-explaining collapses it instantly."
    case "Calibration": return "Meeting her halfway — not all the way — is what gives you the pull."
    case "Connection": return "Real connection requires one person to go first — that's your move."
    case "Texting": return "Restraint in texting reads as confidence, not disinterest."
    case "Dates": return "A specific plan removes friction; a vague plan creates it."
    case "Style": return "First impressions are made before you open your mouth."
    case "Attachment": return "Space given on purpose is different from disappearing — she feels the difference."
    case "EQ": return "Being heard is what people need most and get least."
    case "Context": return "Environment shapes the emotional register before either person speaks."
    case "Apps": return "Specific openers show attention; generic ones show automation."
    case "Relationship": return "Healthy attachment needs two separate people finding a shared pace."
    case "Foundations": return "Understanding the mechanism lets you apply it — not just hope for it."
    default: return "Being interested beats trying to be interesting."
    }
  }

  // MARK: - Signal phrases (single on-screen key phrase per beat)

  private static func hookSignal(for lecture: Lecture) -> String {
    switch lecture.skill {
    case "Opening": return "First seconds matter"
    case "Presence": return "Be here, not perfect"
    case "Frame": return "It's a frame test"
    case "Flow": return "Stay on her beat"
    default: return "Why this works"
    }
  }

  private static func insightSignal(for lecture: Lecture) -> String {
    switch lecture.skill {
    case "Opening": return "Two of three"
    case "Presence": return "Notice, breathe, stay"
    case "Frame": return "Standards first"
    case "Flow": return "One real callback"
    default: return "The core move"
    }
  }

  private static func takeawaySignal(for lecture: Lecture) -> String {
    "You're up"
  }

  // MARK: - Key points (KP1 — highlight-reel captions, ≤ 6 words each)
  //
  // Hook = why this moment matters; Insight = the mechanism; Takeaway = the action.
  // GoodVsBad and Recall are intentionally absent — their on-screen content IS
  // the beat. No timing offsets: LXFIX7 staggers them on a timer client-side.

  static func hookKeyPoints(for lecture: Lecture) -> [String] {
    switch lecture.skill {
    case "Opening":
      return ["Don't overthink it", "One true line", "Timing beats content"]
    case "Presence":
      return ["Armor down first", "Room reads you before you speak", "Calm over flawless"]
    case "Flow":
      return ["Catch the threads she leaves", "Callbacks signal you listened", "Don't fill her silence"]
    case "Confidence":
      return ["Confidence is behavioral", "Shorter, slower, quieter", "Not born — built"]
    case "Banter":
      return ["Ease is the signal", "Light, not clever", "Back-and-forth opens doors"]
    case "Calibration":
      return ["Don't mirror all the way", "Meet her halfway", "Hold your own level"]
    case "Connection":
      return ["Go first — go deeper", "Depth invites depth", "One person has to start"]
    case "Texting":
      return ["Less is more", "Restraint reads as confidence", "Volume kills engagement"]
    case "Dates":
      return ["Lead — don't ask", "Remove her decision fatigue", "A plan is attractive"]
    case "Style":
      return ["You're read in 250ms", "Coherence signals identity", "Your look speaks first"]
    case "Attachment":
      return ["Hold your own pace", "Don't mirror her distance", "Consistency reduces fear"]
    case "EQ":
      return ["She needs to be heard", "Don't rush to fix", "Name what's happening"]
    case "Context":
      return ["Venue primes the mood", "Choose it like your opener", "Environment works for you"]
    case "Apps":
      return ["Specific beats generic", "Stand out in the stack", "One real observation"]
    case "Relationship":
      return ["Stable pace builds trust", "Don't rush — don't disappear", "Be the consistent one"]
    case "Foundations":
      return ["Attraction is modular", "Multiple levers in parallel", "Learn the system first"]
    default:
      return ["Why this works", "One clean move"]
    }
  }

  static func insightKeyPoints(for lecture: Lecture) -> [String] {
    switch lecture.skill {
    case "Opening":
      return ["Voice, eyes, turn-taking", "Hit two — don't chase three", "Ratio beats perfection"]
    case "Presence":
      return ["Natural eye contact intervals", "Chosen calm, not nervous scanning", "Presence is a proximity signal"]
    case "Flow":
      return ["Under 1.5s reply = engaged", "One callback holds the thread", "Warmth: listen and respond"]
    case "Confidence":
      return ["Shorter sentences, slower tempo", "Fewer qualifiers = confident signal", "Behave it — feel it later"]
    case "Banter":
      return ["Back-and-forth signals openness", "Ease, not volume or wit", "Playfulness = openness signal"]
    case "Calibration":
      return ["70% match — not 100%", "Full match reads as mimicry", "Meet halfway, hold there"]
    case "Connection":
      return ["Disclosure is reciprocal", "Go slightly deeper first", "You set the depth ceiling"]
    case "Texting":
      return ["Reply time is a signal", "Short messages hold more tension", "Restraint predicts engagement"]
    case "Dates":
      return ["Specific plan removes friction", "Removes her decision fatigue", "Your confidence signal rises"]
    case "Style":
      return ["First impressions form in 250ms", "Coherence signals identity", "She reads you before words"]
    case "Attachment":
      return ["Hold a consistent rate", "Don't match her distance swings", "Stability breaks the anxious loop"]
    case "EQ":
      return ["Name the emotion aloud", "Being heard lowers the alarm", "Advice raises it — listen first"]
    case "Context":
      return ["Venue primes emotional set points", "Choose it before choosing words", "Environment shifts the baseline"]
    case "Apps":
      return ["Specific openers beat generic ones", "Reference her — don't compliment her", "Signal-to-noise over volume"]
    case "Relationship":
      return ["Stable rate = trust over time", "Don't calibrate to her anxiety", "Be consistent, not reactive"]
    case "Foundations":
      return ["Multiple mechanisms work in parallel", "Learn the architecture first", "Target the right lever"]
    default:
      return ["The core mechanism", "Pick one variable"]
    }
  }

  static func takeawayKeyPoints(for lecture: Lecture) -> [String] {
    switch lecture.skill {
    case "Opening":
      return ["Shorten your first sentence", "Hold one beat longer", "Let the signal land"]
    case "Presence":
      return ["One exhale before speaking", "Name what's real", "Real beats smooth"]
    case "Flow":
      return ["One sentence, one question", "Exit cleanly", "Don't fill every gap"]
    case "Confidence":
      return ["Square shoulders, drop the voice", "Shorten everything", "Be interested, not interesting"]
    case "Banter":
      return ["One line, no explanation", "Match her tempo", "Let it breathe"]
    case "Calibration":
      return ["Match halfway — hold there", "She'll find your level", "Don't chase her energy"]
    case "Connection":
      return ["Ask one real question", "Actually wait for the answer", "Don't pivot to yourself"]
    case "Texting":
      return ["Wait before you reply", "One specific observation", "Don't follow up unprompted"]
    case "Dates":
      return ["Name place, time, backup", "Don't ask what she wants", "Lead — don't check in"]
    case "Style":
      return ["Let the detail land first", "Don't explain your look", "Open on your terms"]
    case "Attachment":
      return ["Give space on purpose", "Don't disappear — don't chase", "She'll come back fuller"]
    case "EQ":
      return ["Don't push when she's off", "Give her room to breathe", "Witness before advising"]
    case "Context":
      return ["Comfortable, specific, easy to extend", "Let the room do half", "Pick the low-pressure spot"]
    case "Apps":
      return ["One thing from her profile", "An observation, not praise", "What only you'd notice"]
    case "Relationship":
      return ["Hold your rate — don't rush", "Let her find the speed", "Consistency is the move"]
    case "Foundations":
      return ["Show up curious, not performing", "Ask what actually interests you", "Weight over polish"]
    default:
      return ["One rep, run it clean", "Stay present"]
    }
  }
}
