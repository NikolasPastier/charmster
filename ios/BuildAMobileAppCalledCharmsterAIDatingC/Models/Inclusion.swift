import SwiftUI

// MARK: - Identity, orientation, partner persona

/// How the user describes themselves. Inclusive set.
enum SelfIdentity: String, CaseIterable, Identifiable, Codable {
    case woman      = "Woman"
    case man        = "Man"
    case nonbinary  = "Nonbinary"
    case selfDescribe = "Self-describe"
    case preferNotToSay = "Prefer not to say"
    var id: String { rawValue }
}

/// Who the user wants to practice talking to.
enum PartnerPresentation: String, CaseIterable, Identifiable, Codable {
    case feminine    = "Feminine"
    case masculine   = "Masculine"
    case androgynous = "Androgynous"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .feminine:    return "person.fill"
        case .masculine:   return "person.fill"
        case .androgynous: return "person.fill"
        }
    }

    var voiceTag: String {
        switch self {
        case .feminine:    return "warm-feminine"
        case .masculine:   return "warm-masculine"
        case .androgynous: return "warm-androgynous"
        }
    }
}

/// Dating context preference for tailoring scenarios.
enum DatingContext: String, CaseIterable, Identifiable, Codable {
    case differentGender = "Different gender than me"
    case sameGender      = "Same gender as me"
    case anyGender       = "Anyone — open"
    case nonbinary       = "Nonbinary or genderqueer partners"
    var id: String { rawValue }
}

/// The configurable AI partner persona used during practice.
struct PartnerPersona: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let presentation: PartnerPresentation
    let blurb: String
    let voiceId: String       // maps to TTS voice when wired
    let palette: PersonaPalette
    /// Asset prefix for expression images, e.g. "Matteo" → "Matteo_neutral".
    let assetPrefix: String

    /// Image name for a given expression. Falls back to `_neutral`.
    func imageName(for expression: PersonaExpression) -> String {
        "\(assetPrefix)_\(expression.rawValue)"
    }

    static let defaults: [PartnerPersona] = [
        PartnerPersona(id: "zoe",
                       displayName: "Zoe",
                       presentation: .feminine,
                       blurb: "Warm, thoughtful, asks the second question.",
                       voiceId: "tts-warm-1",
                       palette: .rose,
                       assetPrefix: "Zoe"),
        PartnerPersona(id: "matteo",
                       displayName: "Matteo",
                       presentation: .masculine,
                       blurb: "Easygoing, dry sense of humor, slow to open up.",
                       voiceId: "tts-warm-2",
                       palette: .ember,
                       assetPrefix: "Matteo"),
        PartnerPersona(id: "sam",
                       displayName: "Sam",
                       presentation: .androgynous,
                       blurb: "Curious, playful, reads the room fast.",
                       voiceId: "tts-warm-3",
                       palette: .iris,
                       assetPrefix: "Zoe"), // fallback until Sam set ships
    ]
}

/// The 15 facial expressions every persona ships with.
/// Asset names: `<Prefix>_<rawValue>` e.g. `Matteo_neutral`, `Zoe_flirty`.
enum PersonaExpression: String, CaseIterable, Codable {
    case neutral, smile, laughing, playful, flirty
    case speaking, listening, thinking, surprised, impressed
    case flustered, bored, cool
    // Two more from the 15-expression set:
    case shy, intrigued

    /// Pick an expression based on a 0...1 connection/feel score.
    static func forFeel(_ feel: Double, isSpeaking: Bool, isListening: Bool) -> PersonaExpression {
        if isSpeaking { return .speaking }
        if isListening { return .listening }
        switch feel {
        case ..<0.25:  return .bored
        case ..<0.40:  return .neutral
        case ..<0.55:  return .thinking
        case ..<0.70:  return .smile
        case ..<0.82:  return .impressed
        case ..<0.92:  return .playful
        default:       return .flirty
        }
    }
}

enum PersonaPalette: String, Codable {
    case rose, ember, iris

    var rimColor: Color {
        switch self {
        case .rose:  return Color(hex: 0xFF4D94)
        case .ember: return Color(hex: 0xFF7A45)
        case .iris:  return Color(hex: 0xA24BFF)
        }
    }
    var fillColors: [Color] {
        switch self {
        case .rose:  return [Color(hex: 0x2A1530), Color(hex: 0x4A1A2E), Color(hex: 0x6B2434)]
        case .ember: return [Color(hex: 0x1F1410), Color(hex: 0x3A1F18), Color(hex: 0x5A2E1F)]
        case .iris:  return [Color(hex: 0x1A1230), Color(hex: 0x2E1B4F), Color(hex: 0x3F2470)]
        }
    }
}

// MARK: - Subscription model (Step 2)

enum SubscriptionStatus: String, Codable {
    case locked    // not subscribed, not in trial
    case trial
    case pro
    case paused
    case canceled
    case expired

    var hasAccess: Bool {
        switch self {
        case .trial, .pro, .paused: return true
        case .locked, .canceled, .expired: return false
        }
    }
}

enum SubscriptionPlan: String, Codable {
    case monthly
    case annual
}

// MARK: - Scenes for live practice (Step 3)

enum PracticeScene: String, CaseIterable, Identifiable, Codable {
    case cafe    = "Cozy café"
    case bar     = "Quiet bar"
    case park    = "Sunny park"
    case rooftop = "Rooftop at dusk"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .cafe:    return "cup.and.saucer.fill"
        case .bar:     return "wineglass.fill"
        case .park:    return "leaf.fill"
        case .rooftop: return "sun.horizon.fill"
        }
    }

    /// Gradient hues that wash the scene behind the avatar.
    var gradient: [Color] {
        switch self {
        case .cafe:    return [Color(hex: 0x1F1410), Color(hex: 0x3A2218), Color(hex: 0x5A3328)]
        case .bar:     return [Color(hex: 0x0F0E1A), Color(hex: 0x1F1A33), Color(hex: 0x3A2A55)]
        case .park:    return [Color(hex: 0x0F1A14), Color(hex: 0x1F3325), Color(hex: 0x2F4A35)]
        case .rooftop: return [Color(hex: 0x1F0E22), Color(hex: 0x4A1B3A), Color(hex: 0x6B2434)]
        }
    }
}
