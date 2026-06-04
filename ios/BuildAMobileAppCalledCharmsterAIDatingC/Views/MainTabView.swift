import SwiftUI

struct MainTabView: View {
    @State private var selection: AppTab = .roadmap

    enum AppTab: Hashable { case roadmap, profile, settings }

    var body: some View {
        Group {
            TabView(selection: $selection) {
                Tab("Roadmap", systemImage: "map.fill", value: AppTab.roadmap) {
                    RoadmapView()
                }
                Tab("Profile", systemImage: "person.crop.circle.fill", value: AppTab.profile) {
                    ProfileView()
                }
                Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
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
