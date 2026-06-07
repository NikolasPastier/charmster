import Foundation

/// Resolves persona expression image URLs from the public Supabase `Avatars` bucket.
///
/// Folder layout in the bucket:
///   `Mia avatar/Mia_<expression>.jpeg`
///   `Matteo avatar/Matteo_<expression>.jpeg`
///   `Zoe avatar/Zoe_<expression>.jpeg`   (note: Zoe uses `_smiling` instead of `_smile`)
enum AvatarImageURL {

    /// Base URL of the Supabase project storage. Falls back to the hardcoded ref if env is missing.
    private static var supabaseBase: String {
        let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
        let base = (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
        return base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// Build the public URL for a given persona + expression.
    /// Returns `nil` if the persona has no remote folder mapped.
    static func url(for persona: PartnerPersona, expression: PersonaExpression) -> URL? {
        guard let folder = folder(for: persona.assetPrefix) else { return nil }
        let suffix = remoteSuffix(prefix: persona.assetPrefix, expression: expression)
        let file = "\(persona.assetPrefix)_\(suffix).jpeg"
        let path = "\(folder)/\(file)"
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
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

    /// Map our code-side expression rawValue to the actual filename suffix in the bucket.
    /// Handles Zoe's `_smiling` quirk and missing `_shy` / `_intrigued` files.
    private static func remoteSuffix(prefix: String, expression: PersonaExpression) -> String {
        switch expression {
        case .smile:
            return prefix == "Zoe" ? "smiling" : "smile"
        case .shy:
            return "flustered"     // closest match available across all 3 personas
        case .intrigued:
            return "impressed"     // closest match available across all 3 personas
        default:
            return expression.rawValue
        }
    }
}
