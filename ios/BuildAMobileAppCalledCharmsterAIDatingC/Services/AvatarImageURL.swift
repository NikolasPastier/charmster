import Foundation

/// Resolves persona expression image URLs from the public Supabase `Avatars` bucket.
enum AvatarImageURL {

    private static var supabaseBase: String {
        let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
        let base = (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
        return base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func url(for persona: PartnerPersona, expression: PersonaExpression) -> URL? {
        guard let folder = folder(for: persona.assetPrefix) else { return nil }
        let suffix = remoteSuffix(prefix: persona.assetPrefix, expression: expression)
        let file = "\(persona.assetPrefix)_\(suffix).jpeg"
        let path = "\(folder)/\(file)"
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "\(supabaseBase)/storage/v1/object/public/Avatars/\(encoded)")
    }

    private static func folder(for prefix: String) -> String? {
        switch prefix {
        case "Mia":    return "Mia avatar"
        case "Matteo": return "Matteo avatar"
        case "Zoe":    return "Zoe avatar"
        default:       return nil
        }
    }

    private static func remoteSuffix(prefix: String, expression: PersonaExpression) -> String {
        switch expression {
        case .smile:     return prefix == "Zoe" ? "smiling" : "smile"
        case .shy:       return "flustered"
        case .intrigued: return "impressed"
        default:         return expression.rawValue
        }
    }
}
