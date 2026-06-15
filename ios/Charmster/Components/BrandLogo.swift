import SwiftUI

/// Charmster brand assets loaded from the Supabase `App logo` bucket.
struct BrandLogo: View {
  enum Size {
    case mark(CGFloat)
    case hero(CGFloat)
    case lockup(CGFloat)
    case heroLockup(CGFloat)
  }

  let size: Size

  static let markURL = URL(
    string:
      "https://uvjtrhvhldeeslgnvhyd.supabase.co/storage/v1/object/public/App%20logo/Untitled%20design-3.png"
  )
  static let wordmarkURL = URL(
    string:
      "https://uvjtrhvhldeeslgnvhyd.supabase.co/storage/v1/object/public/App%20logo/Untitled%20design-4.png"
  )

  var body: some View {
    switch size {
    case .mark(let dim): glyph(dim: dim)
    case .hero(let dim): heroGlyph(dim: dim)
    case .lockup(let dim):
      VStack(spacing: dim * 0.12) {
        glyph(dim: dim)
        wordmark(width: dim * 1.55)
      }
    case .heroLockup(let dim):
      VStack(spacing: dim * 0.14) {
        heroGlyph(dim: dim)
        wordmark(width: dim * 1.7)
      }
    }
  }

  private func heroGlyph(dim: CGFloat) -> some View {
    ZStack {
      Circle()
        .fill(Theme.aura)
        .frame(width: dim + 36, height: dim + 36)
        .shadow(color: Theme.auraGlow, radius: 44)
        .opacity(0.45)
        .blur(radius: 22)
      glyph(dim: dim)
        .shadow(color: Theme.auraGlow.opacity(0.6), radius: 22)
    }
  }

  private func glyph(dim: CGFloat) -> some View {
    remoteImage(url: Self.markURL, fallback: AnyView(fallbackGlyph))
      .frame(width: dim, height: dim)
  }

  private func wordmark(width: CGFloat) -> some View {
    remoteImage(url: Self.wordmarkURL, fallback: AnyView(fallbackWordmark))
      .frame(width: width)
      .frame(maxHeight: width * 0.32)
  }

  @ViewBuilder
  private func remoteImage(url: URL?, fallback: AnyView) -> some View {
    AsyncImage(url: url, transaction: Transaction(animation: .smooth)) { phase in
      switch phase {
      case .success(let image): image.resizable().scaledToFit()
      case .failure: fallback
      case .empty: ProgressView().tint(Theme.textMuted)
      @unknown default: fallback
      }
    }
  }

  private var fallbackGlyph: some View {
    Image(systemName: "heart.fill")
      .resizable().scaledToFit()
      .foregroundStyle(Theme.aura)
  }

  private var fallbackWordmark: some View {
    Text("Charmster")
      .font(.system(size: 32, weight: .heavy, design: .rounded))
      .foregroundStyle(Theme.text)
  }
}

/// The Charmster logo shown at the top of onboarding. Loaded remotely from the
/// public Supabase `App logo` bucket (never bundled locally), with a loading
/// placeholder and an error fallback so it is never blank. AsyncImage caches
/// the download via the shared URLCache.
struct OnboardingLogo: View {
  /// Single source for the onboarding logo URL.
  static let onboarding_logo_url = URL(
    string:
      "https://uvjtrhvhldeeslgnvhyd.supabase.co/storage/v1/object/public/App%20logo/new%20logo.png"
  )

  var body: some View {
    AsyncImage(url: Self.onboarding_logo_url, transaction: Transaction(animation: .smooth)) {
      phase in
      switch phase {
      case .success(let image):
        image.resizable().scaledToFit()
      case .empty:
        ProgressView().tint(Theme.textMuted)
      case .failure:
        Image(systemName: "heart.fill")
          .resizable().scaledToFit()
          .foregroundStyle(Theme.aura)
      @unknown default:
        Image(systemName: "heart.fill")
          .resizable().scaledToFit()
          .foregroundStyle(Theme.aura)
      }
    }
    .frame(height: 120)
    .frame(maxWidth: .infinity)
  }
}
