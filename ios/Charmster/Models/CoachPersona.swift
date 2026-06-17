import Foundation

// MARK: - CoachPersona
//
// The shared foundation for "coaches as named CHARACTERS you join".
// This prompt OWNS this model; the later Lecture-Redesign prompt REUSES it.
// Do not duplicate coach personas elsewhere.
//
// A persona is a human-named character (Theo, Dr. Ray, …) that maps onto one of
// the existing five `CoachStyle` tone engines. We do NOT fork the tone logic:
// the persona feeds the EXISTING coach system prompt by resolving to its
// `CoachStyle`. The in-game UI shows the HUMAN NAME ONLY; the roleTag +
// shortDescription appear only on selection/switching surfaces (onboarding +
// Settings + the coach gallery).

struct CoachPersona: Identifiable, Hashable, Codable {
  /// Stable id, also used as the avatar-clip bucket folder (`coach-clips/{id}`).
  let id: String
  /// In-game display name — the ONLY coach label shown during practice/path.
  let humanName: String
  /// Archetype label, shown only on selection/switching surfaces.
  let roleTag: String
  /// One-line pitch for the gallery card.
  let shortDescription: String
  /// The coach's guiding belief — gallery detail + pre-session memory framing.
  let philosophyLine: String
  /// A representative line in the coach's voice — used on the gallery card.
  let sampleLine: String
  /// Optional ElevenLabs voice id reserved for FUTURE on-demand spoken lines
  /// only. It is DATA-ONLY and must never drive live lecture TTS — lecture
  /// narration always comes from the pre-generated `lecture-audio` MP3s via
  /// `LectureAudioURL`, with on-device `AVSpeechSynthesizer` used solely as a
  /// genuine-404 fallback. Nil until real ElevenLabs ids are wired.
  let elevenVoiceId: String?
  /// The existing tone engine this persona drives. Single source of truth for
  /// system-prompt tone/voice — persona is a character skin over this.
  let style: CoachStyle

  /// SF Symbol fallback used when no avatar clip/still resolves.
  var fallbackSymbol: String { style.icon }

  static let library: [CoachPersona] = [
    .init(
      id: "theo",
      humanName: "Theo",
      roleTag: "Big Brother",
      shortDescription: "Blunt warmth. Calls it straight, never makes you feel small.",
      philosophyLine: "You don't need fixing — you need reps and someone honest in your corner.",
      sampleLine:
        "That opener was fine. The problem was you bailed before she could bite. Run it again.",
      elevenVoiceId: nil,
      style: .bigBrother),
    .init(
      id: "dr_ray",
      humanName: "Dr. Ray",
      roleTag: "Scientist",
      shortDescription: "Mechanisms and patterns. Shows you why it works.",
      philosophyLine:
        "Attraction isn't magic — it's signal, timing, and calibration you can learn.",
      sampleLine: "Your turn-taking ratio was 70/30. Cut your talk-time and watch her lean in.",
      elevenVoiceId: nil,
      style: .scientist),
    .init(
      id: "cole",
      humanName: "Cole",
      roleTag: "Alpha Mentor",
      shortDescription: "Standards, frame, and self-respect. Raises the floor on how you show up.",
      philosophyLine: "Set the standard for yourself first. The right people calibrate to it.",
      sampleLine:
        "Stop auditioning. You held strong eye contact once — that's the whole move. Own it.",
      elevenVoiceId: nil,
      style: .alphaMentor),
    .init(
      id: "noah",
      humanName: "Noah",
      roleTag: "Therapist",
      shortDescription: "Self-compassion and nervous-system first. Safe to be a beginner here.",
      philosophyLine:
        "Regulate the body, and the words follow. We go at the pace your system allows.",
      sampleLine:
        "You froze — that's your alarm system, not a flaw. Let's breathe, then try one line.",
      elevenVoiceId: nil,
      style: .therapist),
    .init(
      id: "leo",
      humanName: "Leo",
      roleTag: "Wingman",
      shortDescription: "Mission framing. Show up, run the play, debrief, repeat.",
      philosophyLine: "Every conversation is a rep. Win or learn — there's no losing.",
      sampleLine: "Tonight's mission: one genuine compliment, then shut up and listen. Go.",
      elevenVoiceId: nil,
      style: .wingman),
  ]

  static let `default` = CoachPersona.library[4]  // Leo / Wingman (matches legacy default)

  static func resolve(id: String?) -> CoachPersona {
    guard let id else { return .default }
    return library.first { $0.id == id } ?? .default
  }

  /// Map a legacy `CoachStyle` onto its persona, so existing `coachMode`
  /// selections migrate cleanly into a selected character.
  static func forStyle(_ style: CoachStyle) -> CoachPersona {
    library.first { $0.style == style } ?? .default
  }
}
