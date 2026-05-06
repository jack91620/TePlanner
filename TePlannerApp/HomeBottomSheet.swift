import SwiftUI
import TePlannerKit

/// Bottom drawer hosting the "最近 / 附近" tabs. Sits over HomeView's
/// AMap and supports three drag detents (peek / medium / large) so the
/// user can keep the map visible while browsing.
///
/// Mirrors the Android home screen's tab row but uses a non-modal
/// SwiftUI sheet with `presentationBackgroundInteraction(.enabled)`
/// so map gestures still work when the sheet is at .small.
struct HomeBottomSheet: View {
    enum Tab: Hashable { case nearby, recent }

    @State private var selectedTab: Tab = .nearby
    private let apiService: APIServiceProtocol
    private let coordinate: (latitude: Double, longitude: Double)?
    private let onSelectStation: (ChargingStation) -> Void
    private let onSelectTrip: (RecentRoute) -> Void

    init(
        apiService: APIServiceProtocol,
        coordinate: (latitude: Double, longitude: Double)?,
        onSelectStation: @escaping (ChargingStation) -> Void,
        onSelectTrip: @escaping (RecentRoute) -> Void
    ) {
        self.apiService = apiService
        self.coordinate = coordinate
        self.onSelectStation = onSelectStation
        self.onSelectTrip = onSelectTrip
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("附近").tag(Tab.nearby)
                Text("最近").tag(Tab.recent)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .accessibilityIdentifier("home_tabs")

            switch selectedTab {
            case .nearby:
                NearbyChargersView(
                    apiService: apiService,
                    coordinate: coordinate,
                    onSelect: onSelectStation
                )
                .accessibilityIdentifier("nearby_tab")
            case .recent:
                RecentTripsView(
                    apiService: apiService,
                    onSelect: onSelectTrip
                )
                .accessibilityIdentifier("recent_tab")
            }
        }
    }
}
