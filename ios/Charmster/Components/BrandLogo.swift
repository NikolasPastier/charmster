import SwiftUI

/// The single Charmster brand lockup (flaming-heart emblem + CHARMSTER wordmark),
/// streamed as one transparent PNG from the public Supabase `App logo` bucket.
///
/// This is the one reusable logo component for the whole app — splash, onboarding,
/// and the top header all render `CharmsterLogo`. The PNG is transparent, so it
/// sits cleanly on both light and dark backgrounds. We never bundle it locally and
/// never stretch it: the image is rendered with `.scaledToFit()` inside a fixed
/// HEIGHT, so the original aspect ratio is always preserved across every device
/// scale (@1x/@2x/@3x is handled automatically by rendering the vector-crisp PNG
/// at a point height). AsyncImage caches the download via the shared URLCache.
struct CharmsterLogo: View {
  /// Rendered height in points. Width follows from the logo's aspect ratio.
  var height: CGFloat = 40
  /// Optional fade-in (used by the splash screen).
  var fadeIn: Bool = false

  @State private var appeared = false

  /// The combined heart + wordmark lockup in the public `App logo` bucket.
  static let lockupURL = URL(
    string:
      "https://uvjtrhvhldeeslgnvhyd.supabase.co/storage/v1/object/public/App%20logo/Charmster%20Logo.png"
  )

  var body: some View {
    AsyncImage(url: Self.lockupURL, transaction: Transaction(animation: .smooth)) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .scaledToFit()  // preserve aspect ratio, never stretch
      case .empty:
        ProgressView()
          .tint(Theme.textMuted)
      case .failure:
        fallback
      @unknown default:
        fallback
      }
    }
    .frame(height: height)
    .frame(maxWidth: .infinity)
    .accessibilityLabel("Charmster")
    .opacity(fadeIn ? (appeared ? 1 : 0) : 1)
    .scaleEffect(fadeIn ? (appeared ? 1 : 0.96) : 1)
    .onAppear {
      guard fadeIn else { return }
      withAnimation(.easeOut(duration: 0.7)) { appeared = true }
    }
  }

  /// Text + SF Symbol fallback so the brand is never blank if the asset fails.
  private var fallback: some View {
    HStack(spacing: height * 0.22) {
      Image(systemName: "heart.fill")
        .resizable()
        .scaledToFit()
        .frame(height: height * 0.86)
        .foregroundStyle(Theme.aura)
      Text("CHARMSTER")
        .font(.system(size: height * 0.62, weight: .heavy, design: .rounded))
        .tracking(1.5)
        .foregroundStyle(Theme.text)
    }
    .frame(height: height)
  }
}

/// Backward-compatible alias: the onboarding hero still calls `OnboardingLogo()`.
struct OnboardingLogo: View {
  var body: some View {
    CharmsterLogo(height: 132)
  }
}

#Preview("Light") {
  VStack(spacing: 40) {
    CharmsterLogo(height: 48)
    CharmsterLogo(height: 80, fadeIn: true)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Theme.bg)
}
