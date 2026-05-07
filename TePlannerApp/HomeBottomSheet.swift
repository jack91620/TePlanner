import SwiftUI
import TePlannerKit

/// Bottom drawer over the AMap. Two modes:
///
/// - No active route → 附近 / 最近 tabs (the default browse experience).
/// - Active route → route summary (origin/dest/SOC/charging stops) plus
///   发送到车辆 / 清除路线 actions. Once the user has dismissed the
///   modal RoutePreviewView, the drawer becomes the persistent place to
///   re-inspect or re-send the trip.
struct HomeBottomSheet: View {
    enum Tab: Hashable { case nearby, recent }

    @State private var selectedTab: Tab = .nearby
    private let apiService: APIServiceProtocol
    private let coordinate: (latitude: Double, longitude: Double)?
    private let activeRoute: RoutePlanResponse?
    private let vehicleId: String?
    private let onSelectStation: (ChargingStation) -> Void
    private let onSelectTrip: (RecentRoute) -> Void
    private let onClearRoute: () -> Void

    init(
        apiService: APIServiceProtocol,
        coordinate: (latitude: Double, longitude: Double)?,
        activeRoute: RoutePlanResponse?,
        vehicleId: String?,
        onSelectStation: @escaping (ChargingStation) -> Void,
        onSelectTrip: @escaping (RecentRoute) -> Void,
        onClearRoute: @escaping () -> Void
    ) {
        self.apiService = apiService
        self.coordinate = coordinate
        self.activeRoute = activeRoute
        self.vehicleId = vehicleId
        self.onSelectStation = onSelectStation
        self.onSelectTrip = onSelectTrip
        self.onClearRoute = onClearRoute
    }

    var body: some View {
        if let plan = activeRoute {
            RouteSummaryDrawerContent(
                plan: plan,
                apiService: apiService,
                vehicleId: vehicleId,
                onClearRoute: onClearRoute
            )
        } else {
            tabsContent
        }
    }

    private var tabsContent: some View {
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

/// Drawer content shown while a route is active. Mirrors RoutePreviewView's
/// summary layout but lives inside the persistent bottom sheet so the
/// trip info is one drag away even after the modal preview is closed.
private struct RouteSummaryDrawerContent: View {
    let plan: RoutePlanResponse
    let apiService: APIServiceProtocol
    let vehicleId: String?
    let onClearRoute: () -> Void

    @State private var sendState: SendState = .idle

    enum SendState: Equatable {
        case idle, sending, sent, failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                summaryCard
                if !plan.warnings.isEmpty {
                    warningsCard
                }
                if !plan.chargingStops.isEmpty {
                    chargingStopsList
                }
                actionButtons
            }
            .padding(16)
        }
        .accessibilityIdentifier("route_summary_drawer")
    }

    private var header: some View {
        HStack {
            Label("当前路线", systemImage: "map.fill")
                .font(.headline)
            Spacer()
        }
        .padding(.top, 4)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption2)
                    .padding(.top, 6)
                Text(plan.origin.name).lineLimit(1)
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption2)
                    .padding(.top, 6)
                Text(plan.destination.name).lineLimit(1)
            }
            Divider().padding(.vertical, 4)
            HStack(spacing: 18) {
                stat(value: formatDistance(plan.totalDistanceKm), caption: "总距离")
                stat(value: formatMinutes(plan.totalDurationMinutes), caption: "总时长")
                stat(value: "\(plan.numChargingStops)", caption: "充电次数")
            }
            HStack(spacing: 18) {
                stat(value: "\(plan.initialSoc)% → \(plan.arrivalSoc)%", caption: "电量")
                if plan.chargingDurationMinutes > 0 {
                    stat(value: formatMinutes(plan.chargingDurationMinutes), caption: "充电时长")
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var warningsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(plan.warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(warning).font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var chargingStopsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("沿途充电站").font(.headline)
            ForEach(plan.chargingStops) { stop in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.tint)
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name).font(.body)
                        if let address = stop.address, !address.isEmpty {
                            Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        HStack(spacing: 12) {
                            Text(formatDistance(stop.distanceFromStartKm))
                            Text("\(stop.arrivalSoc)% → \(stop.departureSoc)%")
                            Text(formatMinutes(stop.chargingDurationMinutes))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await send() }
            } label: {
                sendButtonLabel
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(sendState == .sending || sendState == .sent || vehicleId == nil)
            .accessibilityIdentifier("drawer_send_to_vehicle_button")

            Button(role: .destructive) {
                onClearRoute()
            } label: {
                Label("清除路线", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("drawer_clear_route_button")
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var sendButtonLabel: some View {
        switch sendState {
        case .idle: Label("发送到车辆", systemImage: "paperplane.fill")
        case .sending: ProgressView()
        case .sent: Label("已发送", systemImage: "checkmark.circle.fill")
        case .failed(let message):
            VStack(spacing: 2) {
                Label("重新发送", systemImage: "exclamationmark.triangle")
                Text(message).font(.caption2)
            }
        }
    }

    private func send() async {
        guard let vehicleId else {
            sendState = .failed("未选择车辆")
            return
        }
        guard let lat = plan.destination.lat, let lng = plan.destination.lng else {
            sendState = .failed("目的地缺少坐标")
            return
        }
        sendState = .sending
        let request = NavigationRequest(latitude: lat, longitude: lng, name: plan.destination.name)
        let result = await apiService.sendNavigation(vehicleId: vehicleId, request: request)
        switch result {
        case .success:
            Log.search.notice("nav resent from drawer to \(vehicleId, privacy: .public)")
            sendState = .sent
        case .failure(let error):
            Log.search.error("drawer nav send failed: \(error.localizedDescription, privacy: .public)")
            sendState = .failed(error.localizedDescription)
        }
    }

    private func stat(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分"
    }

    private func formatDistance(_ km: Double) -> String {
        if km < 1 { return "\(Int(km * 1000)) m" }
        if km < 100 { return String(format: "%.1f km", km) }
        return "\(Int(km)) km"
    }
}
