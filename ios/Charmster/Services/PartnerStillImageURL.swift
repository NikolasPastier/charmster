import Foundation
import SwiftUI

/// Resolves the uploaded practice-partner STILL images from the public Supabase
/// `Avatars` bucket.
///
/// Storage layout (one consistent scheme — adding a partner is data-only):
///   `{DisplayName} photoreal/stills/{DisplayName} neutral cutout.jpeg`
///   `{DisplayName} photoreal/stills/{DisplayName} neutral scene.jpeg`
///
/// Filenames contain spaces, so the full object path is percent-encoded.
/// The display name MUST match the storage folder exactly (e.g. "Matteo"),
/// which is why the in-app partner name was aligned to "Matteo" (two t's) —
/// no name mapping is needed.
enum PartnerStillImageURL {

  enum Variant: String {
    /// Transparent-ish bust cutout — used for the small selection cards.
    case cutout
    /// Framed gradient scene — used for the larger "Practicing with …" hero.
    case scene
  }

  private static var supabaseBase: String {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    let base = (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
    return base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  /// Resolve the still URL for a partner display name (the folder key).
  /// Returns `nil` if the name is empty so callers keep their placeholder.
  static func url(displayName: String, variant: Variant = .cutout) -> URL? {
    let name = displayName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return nil }
    let path = "\(name) photoreal/stills/\(name) neutral \(variant.rawValue).jpeg"
    guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
      return nil
    }
    return URL(string: "\(supabaseBase)/storage/v1/object/public/Avatars/\(encoded)")
  }

  /// Convenience for an `AvatarPersona`.
  static func url(for persona: AvatarPersona, variant: Variant = .cutout) -> URL? {
    url(displayName: persona.displayName, variant: variant)
  }
}

/// Loads a partner's uploaded Supabase still and shows `placeholder` while
/// loading or on failure — never a black frame. Cutout for cards, scene for
/// the hero. Adding a partner is data-only (folder + filename scheme).
struct PartnerStillImage<Placeholder: View>: View {
  let displayName: String
  var variant: PartnerStillImageURL.Variant = .cutout
  @ViewBuilder var placeholder: () -> Placeholder

  var body: some View {
    if let url = PartnerStillImageURL.url(displayName: displayName, variant: variant) {
      AsyncImage(url: url, transaction: .init(animation: .easeInOut(duration: 0.25))) { phase in
        switch phase {
        case .success(let image):
          image.resizable().scaledToFill()
        case .empty, .failure:
          placeholder()
        @unknown default:
          placeholder()
        }
      }
    } else {
      placeholder()
    }
  }
}
