import Foundation
import SwiftUI

// MARK: - Coach style

enum CoachStyle: String, CaseIterable, Identifiable, Codable {
  case bigBrother
  case scientist
  case alphaMentor
  case therapist
  case wingman

  var id: String { rawValue }

  var title: String {
    switch self {
    case .bigBrother: return "Big Brother"
    case .scientist: return "Scientist"
    case .alphaMentor: return "Alpha Mentor"
    case .therapist: return "Therapist"
    case .wingman: return "Wingman"
    }
  }

  var blurb: String {
    switch self {
    case .bigBrother: return "Blunt warmth. No fluff, no shaming."
    case .scientist: return "Mechanisms, studies, and patterns."
    case .alphaMentor: return "Standards, frame, and self-respect."
    case .therapist: return "Self-compassion and nervous system first."
    case .wingman: return "Mission framing. Show up, run the play."
    }
  }

  var icon: String {
    switch self {
    case .bigBrother: return "person.line.dotted.person.fill"
    case .scientist: return "atom"
    case .alphaMentor: return "shield.lefthalf.filled"
    case .therapist: return "heart.text.square.fill"
    case .wingman: return "airplane.departure"
    }
  }

  /// AVSpeechSynthesizer voice locale + a delivery tag. Maps to OpenAI TTS in production.
  var ttsVoiceLocale: String {
    switch self {
    case .bigBrother: return "en-US"
    case .scientist: return "en-GB"
    case .alphaMentor: return "en-US"
    case .therapist: return "en-US"
    case .wingman: return "en-AU"
    }
  }

  var ttsRate: Float {
    switch self {
    case .bigBrother: return 0.50
    case .scientist: return 0.48
    case .alphaMentor: return 0.46
    case .therapist: return 0.44
    case .wingman: return 0.52
    }
  }

  var ttsPitch: Float {
    switch self {
    case .bigBrother: return 0.95
    case .scientist: return 1.05
    case .alphaMentor: return 0.90
    case .therapist: return 1.10
    case .wingman: return 1.00
    }
  }
}

// MARK: - Difficulty

enum DifficultyTier: String, CaseIterable, Identifiable, Codable {
  case bronze
  case silver
  case gold

  var id: String { rawValue }
  var title: String {
    switch self {
    case .bronze: return "Bronze"
    case .silver: return "Silver"
    case .gold: return "Gold"
    }
  }
  /// How strongly a session at this tier pulls Aura toward the session
  /// rating. Reuses the legacy 0.8 / 1.0 / 1.3 spread, but now scales the
  /// EMA blend weight in `AppState.applyRewards` — a strong Gold session
  /// moves Aura more (and a weak one moves it down more); a Bronze session
  /// nudges it less. Aura is a 0–100 rolling average, so we never grant
  /// flat "+N" Aura points.
  var tierWeight: Double {
    switch self {
    case .bronze: return 0.8
    case .silver: return 1.0
    case .gold: return 1.3
    }
  }

  /// One-line label describing the tier's effect on Aura, for the
  /// configurator and other surfaces that used to show "×1.3 XP".
  var auraEffectLabel: String {
    switch self {
    case .bronze: return "Smaller Aura swing"
    case .silver: return "Standard Aura swing"
    case .gold: return "Bigger Aura swing"
    }
  }

  /// Minimum session score for a rep to count as a pass (streak kept, mastery-eligible).
  /// Bronze is forgiving; Gold demands a noticeably stronger performance.
  var passThreshold: Int {
    switch self {
    case .bronze: return 55
    case .silver: return 60
    case .gold:   return 68
    }
  }

  var color: Color {
    switch self {
    case .bronze: return Color(hex: 0xCD7F32)
    case .silver: return Color(hex: 0xC0C0C0)
    case .gold: return Theme.gold
    }
  }
}

// MARK: - Aura tier (Spark -> Glow -> Magnetic -> Radiant)

/// The user's overall progress band, derived from the 0–100 `AppState.aura`
/// rolling average. This is the single primary progress metric in the app —
/// the XP / Level system was removed.
enum AuraTier: String, CaseIterable, Codable {
  case spark
  case glow
  case magnetic
  case radiant

  var title: String {
    switch self {
    case .spark: return "Spark"
    case .glow: return "Glow"
    case .magnetic: return "Magnetic"
    case .radiant: return "Radiant"
    }
  }

  /// Tagline shown under the headline number on Profile / Results.
  var blurb: String {
    switch self {
    case .spark: return "Finding your footing."
    case .glow: return "Warming up. Conversations feel easier."
    case .magnetic: return "People lean in. Your reps show."
    case .radiant: return "Calibrated, present, hard to fake."
    }
  }

  var color: Color {
    switch self {
    case .spark: return Theme.teal
    case .glow: return Theme.gold
    case .magnetic: return Theme.aura
    case .radiant: return Theme.auraGlow
    }
  }

  /// Map a 0–100 Aura value to a tier. Bands are tuned so the first
  /// promotion (Spark → Glow) lands around the same place a free user
  /// reaches after a handful of solid sessions.
  static func forAura(_ aura: Int) -> AuraTier {
    switch aura {
    case ..<35: return .spark
    case 35..<60: return .glow
    case 60..<82: return .magnetic
    default: return .radiant
    }
  }
}

// MARK: - Mastery tier (Bronze -> Silver -> Gold)

enum MasteryTier: String, Codable, CaseIterable {
  case none
  case bronze
  case silver
  case gold

  var title: String {
    switch self {
    case .none: return "Not started"
    case .bronze: return "Bronze"
    case .silver: return "Silver"
    case .gold: return "Gold"
    }
  }

  var color: Color {
    switch self {
    case .none: return Theme.textFaint
    case .bronze: return Color(hex: 0xCD7F32)
    case .silver: return Color(hex: 0xC0C0C0)
    case .gold: return Theme.gold
    }
  }

  func advanced() -> MasteryTier {
    switch self {
    case .none: return .bronze
    case .bronze: return .silver
    case .silver: return .gold
    case .gold: return .gold
    }
  }
}

// MARK: - Persona

struct PartnerPersona: Identifiable, Hashable, Codable {
  let id: String
  let displayName: String
  let pronouns: String
  let blurb: String
  let assetPrefix: String  // capitalized look folder, e.g. "Mia"
  let palette: PersonaPalette

  /// FEMALE-only practice looks. Mirrors `AvatarPersona.library` (one row per
  /// look). This is the runtime persona that live practice / scoring consume —
  /// the catalog stays in sync so selection by `avatarLookId` always resolves.
  static let library: [PartnerPersona] = [
    .init(
      id: "mia", displayName: "Mia",
      pronouns: "she/her",
      blurb: "Warm, witty, a little shy on the first beat.",
      assetPrefix: "Mia",
      palette: .init(top: 0x2A1A2B, bottom: 0x16101A)),
    .init(
      id: "ava", displayName: "Ava",
      pronouns: "she/her",
      blurb: "Bright, easy-going, quick to laugh.",
      assetPrefix: "Ava",
      palette: .init(top: 0x2B2230, bottom: 0x161019)),
    .init(
      id: "sofia", displayName: "Sofia",
      pronouns: "she/her",
      blurb: "Playful, expressive, leans into banter.",
      assetPrefix: "Sofia",
      palette: .init(top: 0x2C1F22, bottom: 0x171012)),
    .init(
      id: "mei", displayName: "Mei",
      pronouns: "she/her",
      blurb: "Calm, observant, dry sense of humor.",
      assetPrefix: "Mei",
      palette: .init(top: 0x1F2A2B, bottom: 0x101517)),
    .init(
      id: "nia", displayName: "Nia",
      pronouns: "she/her",
      blurb: "Confident, warm, magnetic energy.",
      assetPrefix: "Nia",
      palette: .init(top: 0x2A2418, bottom: 0x161310)),
  ]

  static let `default` = PartnerPersona.library[0]
}

struct PersonaPalette: Hashable, Codable {
  let top: UInt32
  let bottom: UInt32
  var fillColors: [Color] { [Color(hex: top), Color(hex: bottom)] }
}

enum PersonaExpression: String, Codable, CaseIterable {
  case neutral
  case smile
  case shy
  case intrigued
  case laughing
  case thinking

  /// Pick an expression from a 0-1 feel meter + speaking/listening state.
  static func forFeel(_ feel: Double, isSpeaking: Bool, isListening: Bool) -> PersonaExpression {
    if isSpeaking { return feel > 0.7 ? .laughing : .smile }
    if isListening { return feel > 0.65 ? .intrigued : .thinking }
    return feel > 0.55 ? .smile : .neutral
  }
}

// MARK: - Setting

struct PracticeSetting: Identifiable, Hashable, Codable {
  let id: String
  let title: String
  let icon: String
  let blurb: String

  static let library: [PracticeSetting] = [
    .init(
      id: "coffee_shop", title: "Coffee shop", icon: "cup.and.saucer.fill",
      blurb: "Casual midday energy. Background hum."),
    .init(
      id: "bar", title: "Wine bar", icon: "wineglass.fill",
      blurb: "Soft lighting, leaning in to be heard."),
    .init(
      id: "bookstore", title: "Bookstore", icon: "books.vertical.fill",
      blurb: "Quiet aisles. Plenty of conversation hooks."),
    .init(
      id: "park", title: "Park bench", icon: "leaf.fill",
      blurb: "Open air, slow tempo, dog walkers."),
    .init(
      id: "gym", title: "Gym lounge", icon: "dumbbell.fill",
      blurb: "Post-workout. Higher energy floor."),
    .init(
      id: "house_party", title: "House party", icon: "music.note.house.fill",
      blurb: "Loud, social, lots of cross-currents."),
    .init(
      id: "dinner_date", title: "Dinner date", icon: "fork.knife",
      blurb: "Seated, eye contact, slow burn."),
  ]

  static let `default` = PracticeSetting.library[0]
}

// MARK: - Mode

enum PracticeMode: String, Codable, CaseIterable, Identifiable {
  case videoVoice
  case audioOnly
  case text

  var id: String { rawValue }

  var title: String {
    switch self {
    case .videoVoice: return "Video + voice"
    case .audioOnly: return "Audio only"
    case .text: return "Text"
    }
  }

  var blurb: String {
    switch self {
    case .videoVoice: return "Full review — face, body, voice, synchrony."
    case .audioOnly: return "Voice-only review. Camera off."
    case .text: return "Text-only chat practice."
    }
  }

  var icon: String {
    switch self {
    case .videoVoice: return "video.fill"
    case .audioOnly: return "waveform"
    case .text: return "bubble.left.and.bubble.right.fill"
    }
  }
}
