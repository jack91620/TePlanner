import SwiftUI

/// Top-level view used by the app entry. For now this is a simple TabView
/// holding the AMap smoke test — we'll grow this into the real
/// LoginView / HomeView split once OAuth lands.
struct RootView: View {
    var body: some View {
        TabView {
            AMapDemoView()
                .tabItem {
                    Label("地图", systemImage: "map")
                }

            // Placeholder for the upcoming Tesla flow — the existing
            // TePlannerKit ContentView is preserved here so we can confirm
            // the SPM library is wired into the app bundle correctly.
            PlannerPlaceholderView()
                .tabItem {
                    Label("规划", systemImage: "car")
                }
        }
    }
}

#Preview {
    RootView()
}
