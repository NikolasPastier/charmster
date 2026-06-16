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
    let recall = recallCheck(for: lecture, coach: coach.style)

    let beats: [LectureBeat] = [
      // 1 — HOOK (avatar speaks, emotional)
      LectureBeat(
        id: "\(lecture.id).hook",
        kind: .hook,
        narrationText: content.hook,
        signalPhrase: hookSignal(for: lecture),
        visual: .avatar
      ),
      // 2 — CORE INSIGHT (voiceover + emphasis visual)
      LectureBeat(
        id: "\(lecture.id).insight",
        kind: .coreInsight,
        narrationText: content.coreInsight,
        signalPhrase: insightSignal(for: lecture),
        visual: .contrastCards
      ),
      // 3 — GOOD vs BAD (mode-driven visual)
      LectureBeat(
        id: "\(lecture.id).goodbad",
        kind: .goodVsBad,
        narrationText: goodVsBadNarration(content: content, mode: mode),
        signalPhrase: mode == .texting ? "What you send back" : "What you say out loud",
        visual: mode == .texting ? .chatMockup : .spokenLineCards,
        goodExample: example(from: content.goodExample, mode: mode, isGood: true),
        badExample: example(from: content.badExample, mode: mode, isGood: false)
      ),
      // 4 — RECALL CHECK (one quick active-recall tap)
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
        narrationText: "\(content.practicalTakeaway) \(content.practiceHandoff)",
        signalPhrase: takeawaySignal(for: lecture),
        visual: .avatar
      ),
    ]

    return LectureStory(
      lectureId: lecture.id, coachId: coach.id, conversationMode: mode, beats: beats)
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
    case "Frame": return "Holding tone keeps the frame; explaining yourself collapses it."
    case "Flow": return "A callback proves you listened — that's what makes her stay."
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
}
