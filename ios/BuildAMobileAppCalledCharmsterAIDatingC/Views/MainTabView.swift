import SwiftUI

/// 5-tab Charmster shell: Home · Practice · Progress · Coach · Profile.
/// Practice is the raised center tab.
struct MainTabView: View {
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, practice, progress, coach, profile }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case .home:     RoadmapView()
                case .practice: PracticeHubView()
                case .progress: ProgressDashboardView()
                case .coach:    CoachHubView()
                case .profile:  ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 84)
            }

            CharmsterTabBar(selection: $selection)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
        .background(AuraBackground())
        .trackView("MainTabView")
    }
}

private struct CharmsterTabBar: View {
    @Binding var selection: MainTabView.Tab

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.home, "house.fill", "Home")
            tabItem(.progress, "chart.line.uptrend.xyaxis", "Progress")
            centerButton
            tabItem(.coach, "person.crop.circle.badge.questionmark", "Coach")
            tabItem(.profile, "person.fill", "Profile")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.surface.opacity(0.85))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        )
    }

    private func tabItem(_ tab: MainTabView.Tab, _ icon: String, _ label: String) -> some View {
        let active = selection == tab
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { selection = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label).font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(active ? AnyShapeStyle(Theme.aura) : AnyShapeStyle(Theme.textMuted))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var centerButton: some View {
        Button {
            withAnimation(.spring) { selection = .practice }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.aura)
                    .frame(width: 64, height: 64)
                    .shadow(color: Theme.auraGlow, radius: 20)
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(y: -16)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MainTabView().environment(AppState()).preferredColorScheme(.dark)
}
