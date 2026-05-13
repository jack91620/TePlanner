import SwiftUI
import CoreLocation
import TePlannerKit

/// Bottom drawer over the AMap. Single source of truth for trip
/// info — no separate modal preview. Renders one of four modes:
///
/// - `.loading`  → spinner while RoutePreviewViewModel orchestrates
///                  /routes/route → AMap alongby → /routes/charging-plan
/// - `.error`    → failure message + retry
/// - `.loaded`   → 当前路线 summary (origin/dest/SOC/charging stops)
///                  with 发送到车辆 / 清除路线 actions
/// - `.tabs`     → default 附近 / 最近 browse
///
/// The user drags the drawer up/down via the standard sheet detents
/// (peek / medium / large) so the map stays interactive.
struct HomeBottomSheet: View {
    enum Mode {
        case tabs
        case loading
        case error(String, retry: () -> Void)
        case loaded(RoutePlanResponse)
    }

    enum Tab: Hashable { case nearby, recent }

    @State private var selectedTab: Tab = .nearby
    private let mode: Mode
    private let apiService: APIServiceProtocol
    private let coordinate: (latitude: Double, longitude: Double)?
    private let vehicleId: String?
    private let commandStatusStore: CommandStatusStore?
    private let onSelectStation: (ChargingStation) -> Void
    private let onSelectTrip: (RecentRoute) -> Void
    private let onClearRoute: () -> Void

    init(
        mode: Mode,
        apiService: APIServiceProtocol,
        coordinate: (latitude: Double, longitude: Double)?,
        vehicleId: String?,
        commandStatusStore: CommandStatusStore? = nil,
        onSelectStation: @escaping (ChargingStation) -> Void,
        onSelectTrip: @escaping (RecentRoute) -> Void,
        onClearRoute: @escaping () -> Void
    ) {
        self.mode = mode
        self.apiService = apiService
        self.coordinate = coordinate
        self.vehicleId = vehicleId
        self.commandStatusStore = commandStatusStore
        self.onSelectStation = onSelectStation
        self.onSelectTrip = onSelectTrip
        self.onClearRoute = onClearRoute
    }

    var body: some View {
        switch mode {
        case .tabs:
            tabsContent
        case .loading:
            loadingView
        case .error(let message, let retry):
            errorView(message: message, retry: retry)
        case .loaded(let plan):
            RouteSummaryDrawerContent(
                plan: plan,
                apiService: apiService,
                vehicleId: vehicleId,
                commandStatusStore: commandStatusStore,
                onClearRoute: onClearRoute
            )
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

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView("规划路线…").controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("route_loading")
    }

    private func errorView(message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(Tokens.typographyPlaceholderIconSm)
                .foregroundStyle(.orange)
            Text("路线规划失败").font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            HStack(spacing: 12) {
                Button("重试") { retry() }
                    .buttonStyle(.borderedProminent)
                Button("取消", role: .destructive) { onClearRoute() }
                    .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .accessibilityIdentifier("route_error")
    }
}

/// Drawer content shown once a route is loaded. Replaces the old modal
/// RoutePreviewView entirely — content was duplicated and the modal
/// hid the map.
private struct RouteSummaryDrawerContent: View {
    let plan: RoutePlanResponse
    let apiService: APIServiceProtocol
    let vehicleId: String?
    let commandStatusStore: CommandStatusStore?
    let onClearRoute: () -> Void

    @State private var sendState: SendState = .idle
    @State fileprivate var selectedRouteStop: ChargingStop? = nil

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
        .sheet(item: $selectedRouteStop) { stop in
            // Shared detail view for nearby + along-route stops. The
            // adapter (ChargingStop.toStation) carries through photos /
            // rating / hours that backend now hydrates from AMap; the
            // "规划路线" action is a no-op here because the user is
            // already inside the route plan — we map it to dismiss
            // rather than re-plan.
            ChargingStationDetailView(
                station: stop.toStation(),
                onPlanRoute: { _ in selectedRouteStop = nil }
            )
        }
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
                Text(plan.origin.name ?? "未知地点").lineLimit(1)
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption2)
                    .padding(.top, 6)
                Text(plan.destination.name ?? "未知地点").lineLimit(1)
            }
            Divider().padding(.vertical, 4)
            HStack(spacing: 18) {
                stat(value: formatDistance(plan.totalDistanceKm), caption: "总距离")
                stat(value: formatMinutes(plan.totalDurationMinutes), caption: "总时长")
                stat(value: "\(plan.numChargingStops)", caption: "充电次数")
            }
            HStack(spacing: 18) {
                stat(value: "\(plan.initialSoc)% → \(plan.arrivalSoc)%", caption: "预估电量")
                if plan.chargingDurationMinutes > 0 {
                    stat(value: formatMinutes(plan.chargingDurationMinutes), caption: "充电时长")
                }
            }
        }
        .padding(Tokens.spacingMdPlus)
        .background(Tokens.surfaceCard, in: RoundedRectangle(cornerRadius: 12))
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
        .background(Tokens.colorWashWarning.opacity(Tokens.colorWashWarningAlpha), in: RoundedRectangle(cornerRadius: 10))
    }

    private var chargingStopsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("沿途充电站").font(.headline)
            ForEach(plan.chargingStops) { stop in
                // Each row opens the same ChargingStationDetailView as
                // the 附近 tab — single detail surface, less code, plus
                // the user gets photos / rating / hours on route stops
                // too once backend pulls the extras through (Phase 1
                // 2026-05-11 enrichment).
                Button {
                    selectedRouteStop = stop
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.tint)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stop.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if let address = stop.address, !address.isEmpty {
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
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
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(Tokens.spacingSmPlus)
                    .background(Tokens.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("route_stop_\(stop.stationId)")
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
            .accessibilityIdentifier("send_to_vehicle_button")

            Button(role: .destructive) {
                onClearRoute()
            } label: {
                Label("清除路线", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("clear_route_button")
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
        // Destination came from AMap POI search → GCJ-02. Tesla's
        // navigation_gps_request expects WGS-84. Convert at the
        // outbound boundary so the car navigates to the right pin
        // (otherwise it'd land ~200 m off in mainland China).
        let wgs = CoordConverter.gcj02ToWgs84(
            CLLocationCoordinate2D(latitude: lat, longitude: lng))
        let request = NavigationRequest(
            latitude: wgs.latitude, longitude: wgs.longitude,
            name: plan.destination.name,
        )
        let result = await apiService.sendNavigation(vehicleId: vehicleId, request: request)
        switch result {
        case .success:
            Log.search.notice("nav sent from drawer to \(vehicleId, privacy: .public)")
            sendState = .sent
            // Defensive (B2 completion): if Tesla nav ever gains an
            // expected_state on the backend, this would start writing
            // CommandPending rows; kick the converge poll preemptively
            // so the Hub banner can't get stuck on "正在...等待".
            if let store = commandStatusStore {
                Task { await store.pollUntilSettled() }
            }
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
