import SwiftUI

/// Brief launch/splash screen shown while the app bootstraps. The Charmster
/// lockup is centered and fades in. After a short beat it hands off to the root
/// content. The aura gradient background works on both light and dark themes.
struct SplashView: View {
  var body: some View {
    ZStack {
      AuraBackground()
      CharmsterLogo(height: 86, fadeIn: true)
        .padding(.horizontal, 40)
    }
  }
}

#Preview {
  SplashView()
}
