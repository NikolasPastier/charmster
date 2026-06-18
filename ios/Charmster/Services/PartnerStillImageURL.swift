import Foundation
import SwiftUI

/// Resolves the uploaded practice-partner STILL images from the public Supabase
/// `Avatars` bucket.
///
/// Storage layout (confirmed in audit — adding a look is data-only): each look
/// has a CAPITALIZED top-level folder whose name matches the look, with a
/// `stills/` subfolder:
///   `{Look}/stills/{Look} neutral scene.jpeg`  ← the DISPLAYED photo (branded
///       scene background baked in). This is what the picker thumbnail and any
///       avatar display use.
///   `{Look}/stills/{Look}.jpeg`                ← plain cutout backup only.
///
/// Folders are capitalized and filenames contain spaces, so the EXACT path is
/// stored per look (`AvatarPersona.thumbnailPath`) and percent-encoded here —
/// it is never lowercased or guessed.
enum PartnerStillImageURL {

  /// Public bucket holding all practice-avatar look stills.
  static let bucket = "Avatars"

  private static var supabaseBase: String {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    let base = (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
    return base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  /// Build a public object URL from an EXACT stored object path (with its real
  /// casing and spaces). Returns `nil` if the path is empty.
  ///
  /// NOTE: if the `Avatars` bucket is private, swap this for a signed URL
  /// (`/storage/v1/object/sign/...`) — only this one function changes.
  static func url(objectPath: String) -> URL? {
    let path = objectPath.trimmingCharacters(in: .whitespaces)
    guard !path.isEmpty else { return nil }
    guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
      return nil
    }
    return URL(string: "\(supabaseBase)/storage/v1/object/public/\(bucket)/\(encoded)")
  }

  /// Resolve the displayed still URL for a look. Uses the look's explicit
  /// `thumbnailPath` (the branded "{Look} neutral scene.jpeg" file).
  static func url(for persona: AvatarPersona) -> URL? {
    url(objectPath: persona.thumbnailPath)
  }
}

/// Loads a look's uploaded Supabase still and shows `placeholder` while loading
/// or on failure — never a black frame. Driven by the look's explicit stored
/// `thumbnailPath`, so adding a look is data-only.
struct PartnerStillImage<Placeholder: View>: View {
  /// Exact object path inside the `Avatars` bucket (e.g.
  /// "Mia/stills/Mia neutral scene.jpeg").
  let objectPath: String
  @ViewBuilder var placeholder: () -> Placeholder

  /// Convenience: resolve directly from a look.
  init(persona: AvatarPersona, @ViewBuilder placeholder: @escaping () -> Placeholder) {
    self.objectPath = persona.thumbnailPath
    self.placeholder = placeholder
  }

  init(objectPath: String, @ViewBuilder placeholder: @escaping () -> Placeholder) {
    self.objectPath = objectPath
    self.placeholder = placeholder
  }

  var body: some View {
    if let url = PartnerStillImageURL.url(objectPath: objectPath) {
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
