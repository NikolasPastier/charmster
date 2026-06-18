import Foundation
import Observation

// MARK: - CoachNudgeEngine (UX4)
//
// Deterministic, ON-DEVICE generator of a single `Nudge` from the user's
// latest utterance + the avatar's current feeling. This is intentionally NOT a
// network call: it never blocks the live loop, never spends a token, and fails
// silently (returns nil) when there isn't a confident, useful cue to give.
//
// The generated copy is shaped to the chosen coach persona's VOICE (reusing
// the existing `CoachStyle` tone engine) so a nudge from Theo reads differently
// than one from Dr. Ray — without forking any tone logic.

enum CoachNudgeEngine {

  /// Inputs captured at the moment the user finishes a turn.
  struct Input {
    let userMessage: String
    /// Small recent context (most-recent last). Used only for light heuristics.
    let recentContext: [String]
    /// How the avatar currently feels + a 0..1 intensity (atmosphere).
    let avatarFeeling: AvatarState?
    let feelingIntensity: Double
    /// The lecture skill being practiced, if any (e.g. "Opening", "Flow").
    let skillTarget: String?
    let coach: CoachPersona
    let turnIndex: Int
    /// Whether the last shown nudge was an improvement — used so we never show
    /// two improvements back to back (also enforced by the coordinator).
    let lastWasImprovement: Bool
  }

  // MARK: - Public entry

  /// Produce at most one nudge, or nil. Pure + synchronous + cheap.
  static func generate(_ input: Input) -> Nudge? {
    let msg = input.userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    // Nothing meaningful to coach on a near-empty turn.
    guard msg.count >= 2 else { return nil }

    let words = msg.split { $0 == " " || $0 == "\n" }.count
    let warm = isWarmFeeling(input.avatarFeeling)
    let cool = isCoolFeeling(input.avatarFeeling)

    // 1) Calibration takes priority when the avatar feeling is a strong signal
    //    that the user should adjust (cool / distant), and the level allows it.
    if cool, input.feelingIntensity < 0.42, !input.lastWasImprovement {
      return calibration(input, words: words)
    }

    // 2) Improvement when the turn has a concrete, fixable weakness.
    if let weakness = detectWeakness(msg, words: words), !input.lastWasImprovement {
      return improvement(input, weakness: weakness)
    }

    // 3) Praise when it clearly landed (warm feeling and/or a strong turn).
    if warm || (words >= 6 && words <= 40 && isEngaging(msg)) {
      return praise(input, warm: warm, words: words)
    }

    // Otherwise: stay quiet. Silence is a valid, common output.
    return nil
  }

  // MARK: - Builders

  private static func praise(_ input: Input, warm: Bool, words: Int) -> Nudge {
    let text = voiced(input.coach, lines: praiseLines(input.coach, warm: warm))
    // Confidence rises when the avatar is visibly warm.
    let conf = warm ? 0.82 : 0.66
    return Nudge(
      type: .praise,
      text: text,
      suggestionRewrite: nil,
      rationale: warm
        ? "\(avatarName(input)) warmed up right after that — keep that thread going."
        : "That was the right length and had something for her to grab onto.",
      confidence: conf,
      messageTurnIndex: input.turnIndex,
      coachPersonaId: input.coach.id)
  }

  private static func improvement(_ input: Input, weakness: Weakness) -> Nudge {
    let text = voiced(input.coach, lines: weakness.lines(input.coach))
    return Nudge(
      type: .improvement,
      text: text,
      suggestionRewrite: weakness.rewrite,
      rationale: weakness.why,
      confidence: weakness.confidence,
      messageTurnIndex: input.turnIndex,
      coachPersonaId: input.coach.id)
  }

  private static func calibration(_ input: Input, words: Int) -> Nudge {
    let text = voiced(input.coach, lines: calibrationLines(input.coach))
    return Nudge(
      type: .calibration,
      text: text,
      suggestionRewrite:
        "Ask her something only she can answer — \"what's been the best part of your week?\"",
      rationale: "\(avatarName(input)) is reading a little cool — warm it up before pushing on.",
      confidence: 0.7,
      messageTurnIndex: input.turnIndex,
      coachPersonaId: input.coach.id)
  }

  // MARK: - Weakness detection (one fixable thing only)

  private struct Weakness {
    let rewrite: String?
    let why: String
    let confidence: Double
    let lineKey: LineKey

    enum LineKey { case tooShort, tooLong, allQuestions, lowEffort, closedQuestion }

    func lines(_ coach: CoachPersona) -> [String] {
      CoachNudgeEngine.improvementLines(coach, key: lineKey)
    }
  }

  /// Return the single most useful fixable weakness, or nil.
  private static func detectWeakness(_ msg: String, words: Int) -> Weakness? {
    let lower = msg.lowercased()

    // Very short / low-effort reply.
    if words <= 2 {
      return Weakness(
        rewrite: "Add a reason or a hook: \"Yeah — and it reminded me of …\"",
        why: "One- or two-word replies give her nothing to build on.",
        confidence: 0.78, lineKey: .tooShort)
    }

    // Closed yes/no question that stalls the thread.
    if msg.hasSuffix("?"), words <= 6, startsClosed(lower) {
      return Weakness(
        rewrite: "Open it up: \"What got you into that?\" instead of a yes/no.",
        why: "Closed questions get short answers — open ones keep her talking.",
        confidence: 0.7, lineKey: .closedQuestion)
    }

    // Rambling turn.
    if words >= 55 {
      return Weakness(
        rewrite: "Make your point in one or two lines, then hand it back to her.",
        why: "Long monologues lower her talk-time and she starts to drift.",
        confidence: 0.72, lineKey: .tooLong)
    }

    // Interview mode — stacked questions, no self-disclosure.
    if msg.filter({ $0 == "?" }).count >= 2 {
      return Weakness(
        rewrite: "Share a little first, then ask — trade, don't interrogate.",
        why: "Back-to-back questions feel like an interview, not a connection.",
        confidence: 0.68, lineKey: .allQuestions)
    }

    return nil
  }

  // MARK: - Feeling helpers

  private static func isWarmFeeling(_ s: AvatarState?) -> Bool {
    switch s {
    case .smile, .laugh, .flirty, .reassure: return true
    default: return false
    }
  }

  private static func isCoolFeeling(_ s: AvatarState?) -> Bool {
    switch s {
    case .cool, .thinking, .surprised: return true
    default: return false
    }
  }

  private static func isEngaging(_ msg: String) -> Bool {
    // A turn that either asks something or offers a concrete detail.
    msg.contains("?") || msg.contains(" because ") || msg.split(separator: " ").count >= 8
  }

  private static func startsClosed(_ lower: String) -> Bool {
    ["do you", "are you", "did you", "have you", "is it", "was it", "can you", "would you"]
      .contains { lower.hasPrefix($0) }
  }

  private static func avatarName(_ input: Input) -> String {
    // The coach refers to the practice partner generically — "she" reads
    // natural across looks and avoids leaking the internal persona id.
    "She"
  }

  // MARK: - Voice shaping

  /// Pick a deterministic line from the persona's pool so the same turn yields
  /// a stable cue (no flicker) but different turns vary.
  private static func voiced(_ coach: CoachPersona, lines: [String]) -> String {
    guard !lines.isEmpty else { return "" }
    return lines.first ?? lines[0]
  }

  // MARK: - Persona copy pools
  //
  // One short line per persona. Voice matches the existing CoachStyle tone:
  //   bigBrother — blunt warmth · scientist — mechanism · alphaMentor — frame
  //   therapist — gentle/regulating · wingman — mission framing

  private static func praiseLines(_ coach: CoachPersona, warm: Bool) -> [String] {
    switch coach.style {
    case .bigBrother:
      return [
        warm ? "That landed — she's into it. Keep going." : "Solid. That's the move, run with it."
      ]
    case .scientist:
      return [
        warm
          ? "Her warmth just ticked up — that line worked."
          : "Good signal-to-noise there. Repeat that pattern."
      ]
    case .alphaMentor:
      return [
        warm
          ? "That's the frame. She leaned in — hold it."
          : "Clean and grounded. That's your standard now."
      ]
    case .therapist:
      return [
        warm ? "Nice — you stayed open and she met you there." : "That felt relaxed and real. Good."
      ]
    case .wingman:
      return [
        warm
          ? "Direct hit — she's smiling. Press the advantage."
          : "Good rep. Exactly the play, do it again."
      ]
    }
  }

  private static func calibrationLines(_ coach: CoachPersona) -> [String] {
    switch coach.style {
    case .bigBrother: return ["She's a little cool — warm it up before you push."]
    case .scientist: return ["Her warmth dipped. Add warmth before the next ask."]
    case .alphaMentor: return ["She cooled off. Slow down and re-establish ease."]
    case .therapist: return ["She seems guarded — soften and give her room first."]
    case .wingman: return ["Reading her: she's cooling. Reset with warmth, then advance."]
    }
  }

  private static func improvementLines(_ coach: CoachPersona, key: Weakness.LineKey) -> [String] {
    switch key {
    case .tooShort:
      switch coach.style {
      case .bigBrother: return ["Don't leave her hanging — give her something to grab."]
      case .scientist: return ["Too little signal there. Add a detail she can respond to."]
      case .alphaMentor: return ["Say more than that. Offer something with weight."]
      case .therapist: return ["Try one more line — a reason or a feeling behind it."]
      case .wingman: return ["Thin reply. Add a hook and hand it back."]
      }
    case .tooLong:
      switch coach.style {
      case .bigBrother: return ["You're rambling — make the point, then stop."]
      case .scientist: return ["Talk-time's too high. Trim it and pass the turn."]
      case .alphaMentor: return ["Tighten it. One clean point beats five loose ones."]
      case .therapist: return ["That was a lot — shorten it so she can come in."]
      case .wingman: return ["Cut it short, then let her run with it."]
      }
    case .allQuestions:
      switch coach.style {
      case .bigBrother: return ["Quit interviewing — share something first."]
      case .scientist: return ["Two questions stacked. Disclose, then ask once."]
      case .alphaMentor: return ["Trade, don't interrogate. Give before you take."]
      case .therapist: return ["Lead with a bit of you before the next question."]
      case .wingman: return ["Less interrogation — one share, one ask."]
      }
    case .closedQuestion:
      switch coach.style {
      case .bigBrother: return ["Open that up — yes/no kills the thread."]
      case .scientist: return ["Closed question = short answer. Make it open."]
      case .alphaMentor: return ["Ask something that earns a real answer, not yes/no."]
      case .therapist: return ["Try an open question so she can open up."]
      case .wingman: return ["Swap that yes/no for an open one — keep her talking."]
      }
    case .lowEffort:
      return ["Give her a little more to work with."]
    }
  }
}

// MARK: - CoachNudgeCoordinator (rate-limit / anti-spam / lifecycle)
//
// Owns the SHOWN nudge state for the live screen. Enforces the required
// anti-spam rules, drives auto-hide for praise, and never lets two
// improvement nudges fire back to back. View binds to `current`.

@Observable
@MainActor
final class CoachNudgeCoordinator {

  /// The nudge currently visible (nil = bar hidden).
  private(set) var current: Nudge?
  /// Whether the user has expanded the rewrite ("Try this").
  var showRewrite: Bool = false
  /// Whether the user has expanded the rationale ("Why").
  var showWhy: Bool = false

  private var level: NudgeLevel = .coaching
  private var lastShownTurn: Int = -100
  private var lastShownType: NudgeType?
  private var lastProcessedTurn: Int = -1
  private var hideTask: Task<Void, Never>?

  func configure(level: NudgeLevel) {
    self.level = level
  }

  /// Feed a freshly-finished user turn. Builds and (maybe) shows a nudge.
  /// Returns true if a nudge was shown (for optional haptics upstream).
  @discardableResult
  func handleUserTurn(
    userMessage: String,
    recentContext: [String],
    avatarFeeling: AvatarState?,
    feelingIntensity: Double,
    skillTarget: String?,
    coach: CoachPersona,
    turnIndex: Int
  ) -> Bool {
    guard level != .off else { return false }
    // De-dupe: only process each turn once.
    guard turnIndex > lastProcessedTurn else { return false }
    lastProcessedTurn = turnIndex

    // Rate limit: minimum gap between shown nudges.
    guard turnIndex - lastShownTurn >= level.minTurnGap else { return false }

    let input = CoachNudgeEngine.Input(
      userMessage: userMessage,
      recentContext: recentContext,
      avatarFeeling: avatarFeeling,
      feelingIntensity: feelingIntensity,
      skillTarget: skillTarget,
      coach: coach,
      turnIndex: turnIndex,
      lastWasImprovement: lastShownType == .improvement)

    guard let nudge = CoachNudgeEngine.generate(input) else { return false }

    // Minimal level only surfaces praise.
    if !level.allowsCriticalNudges, nudge.type != .praise { return false }

    // Confidence gate.
    guard nudge.confidence >= level.confidenceFloor else { return false }

    // Never two improvements back to back (defense-in-depth with the engine).
    if nudge.type == .improvement, lastShownType == .improvement { return false }

    show(nudge)
    return true
  }

  func dismiss() {
    hideTask?.cancel()
    hideTask = nil
    current = nil
    showRewrite = false
    showWhy = false
  }

  // MARK: - Internal

  private func show(_ nudge: Nudge) {
    hideTask?.cancel()
    showRewrite = false
    showWhy = false
    current = nudge
    lastShownTurn = nudge.messageTurnIndex
    lastShownType = nudge.type

    if let secs = nudge.autoHideSeconds {
      let id = nudge.id
      hideTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(secs * 1_000_000_000))
        guard !Task.isCancelled else { return }
        // Only auto-hide if it's still the same nudge and the user hasn't
        // expanded a detail chip (don't yank away something they're reading).
        guard let self else { return }
        if self.current?.id == id, !self.showRewrite, !self.showWhy {
          self.current = nil
        }
      }
    }
  }
}
