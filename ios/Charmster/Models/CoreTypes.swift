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
        case .bigBrother:  return "Big Brother"
        case .scientist:   return "Scientist"
        case .alphaMentor: return "Alpha Mentor"
        case .therapist:   return "Therapist"
        case .wingman:     return "Wingman"
        }
    }

    var blurb: String {
        switch self {
        case .bigBrother:  return "Blunt warmth. No fluff, no shaming."
        case .scientist:   return "Mechanisms, studies, and patterns."
        case .alphaMentor: return "Standards, frame, and self-respect."
        case .therapist:   return "Self-compassion and nervous system first."
        case .wingman:     return "Mission framing. Show up, run the play."
        }
    }

    var icon: String {
        switch self {
        case .bigBrother:  return "person.line.dotted.person.fill"
        case .scientist:   return "atom"
        case .alphaMentor: return "shield.lefthalf.filled"
        case .therapist:   return "heart.text.square.fill"
        case .wingman:     return "airplane.departure"
        }
    }

    /// AVSpeechSynthesizer voice locale + a delivery tag. Maps to OpenAI TTS in production.
    var ttsVoiceLocale: String {
        switch self {
        case .bigBrother:  return "en-US"
        case .scientist:   return "en-GB"
        case .alphaMentor: return "en-US"
        case .therapist:   return "en-US"
        case .wingman:     return "en-AU"
        }
    }

    var ttsRate: Float {
        switch self {
        case .bigBrother:  return 0.50
        case .scientist:   return 0.48
        case .alphaMentor: return 0.46
        case .therapist:   return 0.44
        case .wingman:     return 0.52
        }
    }

    var ttsPitch: Float {
        switch self {
        case .bigBrother:  return 0.95
        case .scientist:   return 1.05
        case .alphaMentor: return 0.90
        case .therapist:   return 1.10
        case .wingman:     return 1.00
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
        case .gold:   return "Gold"
        }
    }
    var xpMultiplier: Double {
        switch self {
        case .bronze: return 0.8
        case .silver: return 1.0
        case .gold:   return 1.3
        }
    }
    var color: Color {
        switch self {
        case .bronze: return Color(hex: 0xCD7F32)
        case .silver: return Color(hex: 0xC0C0C0)
        case .gold:   return Theme.gold
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
        case .none:   return "Not started"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold:   return "Gold"
        }
    }

    var color: Color {
        switch self {
        case .none:   return Theme.textFaint
        case .bronze: return Color(hex: 0xCD7F32)
        case .silver: return Color(hex: 0xC0C0C0)
        case .gold:   return Theme.gold
        }
    }

    func advanced() -> MasteryTier {
        switch self {
        case .none:   return .bronze
        case .bronze: return .silver
        case .silver: return .gold
        case .gold:   return .gold
        }
    }
}

// MARK: - Persona

struct PartnerPersona: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let pronouns: String
    let blurb: String
    let assetPrefix: String   // "Mia" | "Matteo" | "Zoe"
    let palette: PersonaPalette

    static let library: [PartnerPersona] = [
        .init(id: "mia", displayName: "Mia",
              pronouns: "she/her",
              blurb: "Warm, witty, a little shy on the first beat.",
              assetPrefix: "Mia",
              palette: .init(top: 0x2A1A2B, bottom: 0x16101A)),
        .init(id: "matteo", displayName: "Matteo",
              pronouns: "he/him",
              blurb: "Confident, playful, reads the room fast.",
              assetPrefix: "Matteo",
              palette: .init(top: 0x1A2230, bottom: 0x10141A)),
        .init(id: "zoe", displayName: "Zoe",
              pronouns: "they/them",
              blurb: "Androgynous, dry humor, low-key intense.",
              assetPrefix: "Zoe",
              palette: .init(top: 0x1F2A22, bottom: 0x101410))
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
        .init(id: "coffee_shop",  title: "Coffee shop",     icon: "cup.and.saucer.fill",
              blurb: "Casual midday energy. Background hum."),
        .init(id: "bar",          title: "Wine bar",        icon: "wineglass.fill",
              blurb: "Soft lighting, leaning in to be heard."),
        .init(id: "bookstore",    title: "Bookstore",       icon: "books.vertical.fill",
              blurb: "Quiet aisles. Plenty of conversation hooks."),
        .init(id: "park",         title: "Park bench",      icon: "leaf.fill",
              blurb: "Open air, slow tempo, dog walkers."),
        .init(id: "gym",          title: "Gym lounge",      icon: "dumbbell.fill",
              blurb: "Post-workout. Higher energy floor."),
        .init(id: "house_party",  title: "House party",     icon: "music.note.house.fill",
              blurb: "Loud, social, lots of cross-currents."),
        .init(id: "dinner_date",  title: "Dinner date",     icon: "fork.knife",
              blurb: "Seated, eye contact, slow burn.")
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
        case .audioOnly:  return "Audio only"
        case .text:       return "Text"
        }
    }

    var blurb: String {
        switch self {
        case .videoVoice: return "Full review — face, body, voice, synchrony."
        case .audioOnly:  return "Voice-only review. Camera off."
        case .text:       return "Text-only chat practice."
        }
    }

    var icon: String {
        switch self {
        case .videoVoice: return "video.fill"
        case .audioOnly:  return "waveform"
        case .text:       return "bubble.left.and.bubble.right.fill"
        }
    }
}
