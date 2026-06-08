import SwiftUI

/// Charmster brand logo loaded from the Supabase `App logo` bucket.
/// The asset has a transparent background, so we render it without surface fills
/// or rounded clipping — the glyph itself carries the shape.
struct BrandLogo: View {
    enum Size {
        case mark(CGFloat)     // square logo mark
        case hero(CGFloat)     // hero with glow ring
    }

    let size: Size

    static let url = URL(string:
        "https://uvjtrhvhldeeslgnvhyd.supabase.co/storage/v1/object/public/App%20logo/Untitled%20design.png"
    )

    var body: some View {
        switch size {
        case .mark(let dim):
            logoImage
                .frame(width: dim, height: dim)
        case .hero(let dim):
            ZStack {
                Circle()
                    .fill(Theme.aura)
                    .frame(width: dim + 28, height: dim + 28)
                    .shadow(color: Theme.auraGlow, radius: 40)
                    .opacity(0.45)
                    .blur(radius: 18)
                logoImage
                    .frame(width: dim, height: dim)
                    .shadow(color: Theme.auraGlow.opacity(0.6), radius: 20)
            }
        }
    }

    @ViewBuilder
    private var logoImage: some View {
        AsyncImage(url: Self.url, transaction: Transaction(animation: .smooth)) { phase in
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

    private var fallback: some View {
        Image(systemName: "heart.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Theme.aura)
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
