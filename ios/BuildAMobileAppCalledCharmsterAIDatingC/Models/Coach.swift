import SwiftUI

/// The 5 selectable coach archetypes per the Charmster spec.
enum CoachMode: String, Codable, CaseIterable, Identifiable {
    case bigBrother  = "big_brother"
    case scientist   = "scientist"
    case alphaMentor = "alpha_mentor"
    case therapist   = "therapist"
    case wingman     = "wingman"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bigBrother:  return "Big Brother"
        case .scientist:   return "Scientist"
        case .alphaMentor: return "Alpha Mentor"
        case .therapist:   return "Therapist"
        case .wingman:     return "Wingman"
        }
    }

    var emoji: String {
        switch self {
        case .bigBrother:  return "👪"
        case .scientist:   return "🧐"
        case .alphaMentor: return "🔥"
        case .therapist:   return "🌱"
        case .wingman:     return "🎉"
        }
    }

    var tagline: String {
        switch self {
        case .bigBrother:  return "Warm, steady, has your back"
        case .scientist:   return "Data-driven, calm, precise"
        case .alphaMentor: return "Direct, high standards"
        case .therapist:   return "Gentle, reflective, safe"
        case .wingman:     return "Playful, real, in your corner"
        }
    }

    var icon: String {
        switch self {
        case .bigBrother:  return "person.2.fill"
        case .scientist:   return "atom"
        case .alphaMentor: return "flame.fill"
        case .therapist:   return "leaf.fill"
        case .wingman:     return "party.popper.fill"
        }
    }
}

// MARK: - Personalization quiz

enum OnbGoal: String, CaseIterable, Identifiable {
    case datingApps   = "Dating apps"
    case approaching  = "Approaching in person"
    case keepConvo    = "Keeping convos going"
    case funFlirty    = "Being more fun & flirty"
    case readSignals  = "Reading signals"
    case nerves       = "Nerves & anxiety"
    case firstDates   = "First dates"
    case relationship = "Dates → relationship"
    case texting      = "Texting"
    case notSure      = "Not sure yet"
    var id: String { rawValue }

    /// Recommended starting track.
    var recommendedTrack: Int {
        switch self {
        case .datingApps:   return 11
        case .approaching:  return 2
        case .keepConvo:    return 3
        case .funFlirty:    return 4
        case .readSignals:  return 5
        case .nerves:       return 8
        case .firstDates:   return 12
        case .relationship: return 13
        case .texting:      return 10
        case .notSure:      return 1
        }
    }
}

enum OnbExperience: String, CaseIterable, Identifiable {
    case new = "New to dating"
    case some = "Some experience"
    case experienced = "Plenty of experience"
    var id: String { rawValue }

    var defaultTier: DifficultyTier {
        switch self {
        case .new: return .bronze
        case .some, .experienced: return .silver
        }
    }
}

enum OnbFlirtingStyle: String, CaseIterable, Identifiable {
    case playful = "Playful & teasing"
    case sincere = "Warm & sincere"
    case witty   = "Dry & witty"
    case bold    = "Bold & forward"
    var id: String { rawValue }
}

enum OnbFocusArea: String, CaseIterable, Identifiable {
    case openers   = "Openers"
    case threading = "Keeping it flowing"
    case humor     = "Being funnier"
    case signals   = "Reading her cues"
    case presence  = "Body & presence"
    case depth     = "Going deeper"
    case nerves    = "Calming nerves"
    case closing   = "Asking her out"
    var id: String { rawValue }
}

enum DifficultyTier: String, CaseIterable, Identifiable, Codable {
    case bronze, silver, gold
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var multiplier: Double {
        switch self {
        case .bronze: return 0.8
        case .silver: return 1.0
        case .gold:   return 1.3
        }
    }
    var blurb: String {
        switch self {
        case .bronze: return "Warm & forgiving"
        case .silver: return "Neutral & realistic"
        case .gold:   return "Reserved & skeptical"
        }
    }
}

enum AttachmentLabel: String {
    case secureLeaning   = "Secure-leaning"
    case anxiousLeaning  = "Anxious-leaning"
    case avoidantLeaning = "Avoidant-leaning"
    case mixed           = "Mixed"

    var strengthLine: String {
        switch self {
        case .secureLeaning:   return "You bring calm steadiness — a real superpower in early dating."
        case .anxiousLeaning:  return "You care deeply. We'll channel that warmth without the spirals."
        case .avoidantLeaning: return "You're independent. We'll build the bridges, on your terms."
        case .mixed:           return "You're complex — that becomes range once you know your patterns."
        }
    }
}

struct QuizResult {
    var goal: OnbGoal?
    var experience: OnbExperience?
    var focusAreas: Set<OnbFocusArea> = []
    var attachmentAnxiety: Double = 2.5   // 1...5
    var attachmentAvoidance: Double = 2.5 // 1...5
    var flirting: OnbFlirtingStyle?
    var confidence: Double = 50           // 0...100
    var coach: CoachMode?
    var dailyMinutes: Int = 10
    var reminderEnabled: Bool = true
    var username: String = ""

    var attachmentLabel: AttachmentLabel {
        let hiAnx = attachmentAnxiety >= 3.0
        let hiAvd = attachmentAvoidance >= 3.0
        switch (hiAnx, hiAvd) {
        case (false, false): return .secureLeaning
        case (true,  false): return .anxiousLeaning
        case (false, true):  return .avoidantLeaning
        case (true,  true):  return .mixed
        }
    }

    var recommendedTrack: Int {
        // High confidence rerouted to Confidence track first.
        if confidence >= 67 { return 8 }
        return goal?.recommendedTrack ?? 1
    }

    var defaultTier: DifficultyTier {
        if confidence >= 67 { return .bronze }
        return experience?.defaultTier ?? .silver
    }
}
