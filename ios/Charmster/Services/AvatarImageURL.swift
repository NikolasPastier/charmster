import Foundation

/// Resolves practice-look still image URLs from the public Supabase `Avatars`
/// bucket.
///
/// All looks now share one consistent, data-driven still layout
/// (`{Look}/stills/{Look} neutral scene.jpeg`), resolved through
/// `PartnerStillImageURL`. There are no per-expression image sets uploaded, so
/// this returns the look's neutral-scene still for any expression. (Per-state
/// motion is handled by `AvatarClipCatalog`, not here.)
enum AvatarImageURL {

  /// The displayed still for a look. `expression` is accepted for call-site
  /// compatibility but currently always resolves to the neutral-scene still.
  static func url(for persona: PartnerPersona, expression: PersonaExpression) -> URL? {
    let look = AvatarPersona.resolve(from: persona.id)
    return PartnerStillImageURL.url(for: look)
  }
}
