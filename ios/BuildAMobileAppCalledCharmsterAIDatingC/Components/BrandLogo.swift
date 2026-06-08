import SwiftUI

/// Charmster brand assets loaded from the Supabase `App logo` bucket.
/// Both PNGs are transparent — render them without surface fills or clipping.
struct BrandLogo: View {
    enum Size {
        case mark(CGFloat)          // square glyph only
        case hero(CGFloat)          // glyph + glow aura
        case lockup(CGFloat)        // glyph stacked above "Charmster" wordmark
        case heroLockup(CGFloat)    // glow aura + glyph + wordmark below
    }

    let size: Size

    static let markURL = URL(string:
        "https://uvjtrhvhldeeslgnvhyd.supabase.co/storage/v1/object/public/App%20logo/Untitled%20design-3.png"
    )
    static let wordmarkURL = URL(string:
        "https://uvjtrhvhldeeslgnvhyd.supabase.co/storage/v1/object/public/App%20logo/Untitled%20design-4.png"
    )

    var body: some View {
        switch size {
        case .mark(let dim):
            glyph(dim: dim)
        case .hero(let dim):
            heroGlyph(dim: dim)
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

    // MARK: - Pieces

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
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                fallback
            case .empty:
                ProgressView().tint(Theme.textMuted)
            @unknown default:
                fallback
            }
        }
    }

    private var fallbackGlyph: some View {
        Image(systemName: "heart.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Theme.aura)
    }

    private var fallbackWordmark: some View {
        Text("Charmster")
            .font(.system(size: 32, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 36) {
            BrandLogo(size: .heroLockup(150))
            BrandLogo(size: .lockup(72))
            BrandLogo(size: .mark(48))
        }
    }
    .preferredColorScheme(.dark)
}
