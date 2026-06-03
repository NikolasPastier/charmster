import SwiftUI

struct MainTabView: View {
    @State private var tab: Tab = .roadmap

    enum Tab: Hashable { case roadmap, profile, settings }

    var body: some View {
        Group {
            TabView(selection: $tab) {
                Tab("Roadmap", systemImage: "map.fill", value: Tab.roadmap) {
                    RoadmapView()
                }
                Tab("Profile", systemImage: "person.crop.circle.fill", value: Tab.profile) {
                    ProfileView()
                }
                Tab("Settings", systemImage: "gearshape.fill", value: Tab.settings) {
                    SettingsView()
                }
            }
            .tint(Theme.accent)
        }
        .trackView("MainTabView")
    }
}

#Preview {
    MainTabView().environment(AppState()).preferredColorScheme(.dark)
}
