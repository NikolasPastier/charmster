import SwiftUI

/// Charmster brand logo loaded from the Supabase `App logo` bucket.
/// Falls back to a heart glyph if the network image fails to load.
struct BrandLogo: View {
    enum Size {
        case mark(CGFloat)     // square logo mark
        case hero(CGFloat)     // hero with glow ring
    }

    let size: Size

    static let url = URL(string:
        "https://uvjtrhvhldeeslgnvhyd.supabase.co/storage/v1/object/public/App%20logo/Minimal_app_logo_Charmster_202606071605-2.jpeg"
    )

    var body: some View {
        switch size {
        case .mark(let dim):
            logoImage
                .frame(width: dim, height: dim)
                .clipShape(RoundedRectangle(cornerRadius: dim * 0.22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: dim * 0.22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        case .hero(let dim):
            ZStack {
                Circle()
                    .fill(Theme.aura)
                    .frame(width: dim + 28, height: dim + 28)
                    .shadow(color: Theme.auraGlow, radius: 40)
                    .opacity(0.55)
                logoImage
                    .frame(width: dim, height: dim)
                    .clipShape(RoundedRectangle(cornerRadius: dim * 0.24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: dim * 0.24, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 14)
            }
        }
    }

    @ViewBuilder
    private var logoImage: some View {
        AsyncImage(url: Self.url, transaction: Transaction(animation: .smooth)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                fallback
            case .empty:
                ZStack {
                    Theme.surface
                    ProgressView().tint(Theme.textMuted)
                }
            @unknown default:
                fallback
            }
        }
    }

    private var fallback: some View {
        ZStack {
            Theme.aura
            Image(systemName: "heart.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 30) {
            BrandLogo(size: .hero(140))
            BrandLogo(size: .mark(48))
        }
    }
    .preferredColorScheme(.dark)
}
