import SwiftUI
import UIKit

/// The ONE consistent avatar for the HUMAN user (not the AI partner).
///
/// Resolution order:
///  1. Locally cached profile photo (instant, offline, pre-auth).
///  2. Remote public URL from `profilePhotoPath` (cross-device after sync).
///  3. Generated fallback: the user's initials over the brand aura gradient,
///     or a person silhouette when there's no name yet.
///
/// Use this everywhere the user's own face should appear so onboarding,
/// Settings, Profile, and the plan reveal stay identical.
struct UserAvatarView: View {
  let name: String
  let photoPath: String
  var size: CGFloat = 64
  /// Bump to force a reload after the photo changes in the same session.
  var reloadToken: Int = 0

  @State private var cached: UIImage?

  var body: some View {
    ZStack {
      if let cached {
        Image(uiImage: cached)
          .resizable()
          .scaledToFill()
      } else if let url = UserAvatarStore.publicURL(for: photoPath) {
        AsyncImage(url: url, transaction: Transaction(animation: .smooth)) { phase in
          switch phase {
          case .success(let image): image.resizable().scaledToFill()
          case .empty: fallback.overlay(ProgressView().tint(.white.opacity(0.7)))
          default: fallback
          }
        }
      } else {
        fallback
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
    .task(id: reloadToken) { cached = UserAvatarStore.cachedImage() }
    .accessibilityLabel(Text(initials.isEmpty ? "Your profile photo" : "\(name) profile photo"))
    .accessibilityAddTraits(.isImage)
  }

  private var fallback: some View {
    ZStack {
      Theme.auraGradient
      if initials.isEmpty {
        Image(systemName: "person.fill")
          .font(.system(size: size * 0.46, weight: .semibold))
          .foregroundStyle(.white.opacity(0.92))
      } else {
        Text(initials)
          .font(.system(size: size * 0.4, weight: .heavy, design: .rounded))
          .foregroundStyle(.white)
      }
    }
  }

  private var initials: String {
    let parts = name.trimmingCharacters(in: .whitespaces)
      .split(separator: " ")
      .prefix(2)
      .compactMap { $0.first.map(String.init) }
    return parts.joined().uppercased()
  }
}

#Preview {
  HStack(spacing: 20) {
    UserAvatarView(name: "Alex Rivera", photoPath: "", size: 80)
    UserAvatarView(name: "", photoPath: "", size: 80)
  }
  .padding()
  .background(Theme.bg)
}
