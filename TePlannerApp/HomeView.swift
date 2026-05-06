import SwiftUI
import TePlannerKit
import MAMapKit

/// Phase 1 home screen: AMap centered on the user's primary vehicle,
/// with a battery / range / state header and a refresh button. Offline
/// and waking states surface in the header so the user knows what's
/// going on while the wake-retry loop runs.
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let apiService: APIServiceProtocol
    private let authSession: AuthSession
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var pendingDestination: POIResult?
    @State private var pendingStation: ChargingStation?
    @State private var currentRoute: RoutePlanResponse?
    @State private var showingUnbindConfirm = false
    @State private var unbindError: String?

    init(apiService: APIServiceProtocol, authSession: AuthSession) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            apiService: apiService,
            authSession: authSession
        ))
        self.apiService = apiService
        self.authSession = authSession
    }

    var body: some View {
        ZStack(alignment: .top) {
            AMapVehicleMapView(
                coordinate: viewModel.coordinate.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                vehicleTitle: viewModel.displayName ?? "我的 Tesla",
                batteryLevel: viewModel.batteryLevel,
                route: currentRoute
            )
            .ignoresSafeArea()

            statusBar
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
        .task {
            await viewModel.load()
            viewModel.startPolling()
        }
        .onDisappear { viewModel.stopPolling() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: viewModel.startPolling()
            default: viewModel.stopPolling()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityIdentifier("home_search_button")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("刷新", systemImage: "arrow.clockwise") {
                        Task { await viewModel.refresh() }
                    }
                    if currentRoute != nil {
                        Button("清除路线", systemImage: "xmark.circle") {
                            currentRoute = nil
                        }
                    }
                    Button("设置", systemImage: "gearshape") {
                        showingSettings = true
                    }
                    Divider()
                    Button("退出登录", systemImage: "arrow.right.square", role: .destructive) {
                        authSession.logout()
                    }
                    Button("解绑 Tesla 账户", systemImage: "link.badge.plus", role: .destructive) {
                        showingUnbindConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("home_menu_button")
            }
        }
        .sheet(isPresented: .constant(true)) {
            HomeBottomSheet(
                apiService: apiService,
                coordinate: viewModel.coordinate,
                onSelectStation: { station in
                    pendingStation = station
                },
                onSelectTrip: { trip in
                    Log.app.notice("recent trip tapped: id=\(trip.id, privacy: .public)")
                    if let lat = trip.destination.lat, let lng = trip.destination.lng {
                        pendingDestination = POIResult(
                            id: "trip-\(trip.id)",
                            name: trip.destination.address ?? "目的地",
                            address: trip.destination.address ?? "",
                            latitude: lat,
                            longitude: lng
                        )
                    }
                }
            )
            .presentationDetents([.height(220), .medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
            .sheet(isPresented: $showingSearch) {
                SearchView(service: AMapPOISearchService()) { result in
                    Log.app.notice("destination picked: \(result.name, privacy: .public) (\(result.latitude), \(result.longitude))")
                    pendingDestination = result
                }
            }
            .sheet(item: $pendingStation) { station in
                ChargingStationDetailView(station: station) { picked in
                    pendingDestination = POIResult(
                        id: picked.id,
                        name: picked.name,
                        address: picked.address ?? "",
                        latitude: picked.latitude,
                        longitude: picked.longitude
                    )
                }
            }
            .sheet(item: $pendingDestination) { destination in
                RoutePreviewView(
                    apiService: apiService,
                    destination: destination,
                    origin: viewModel.coordinate.map {
                        LocationInput(latitude: $0.latitude, longitude: $0.longitude, address: nil)
                    },
                    currentSoc: viewModel.batteryLevel,
                    vehicleId: viewModel.vehicle?.id,
                    onPlanLoaded: { plan in currentRoute = plan }
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .confirmationDialog(
                "解绑 Tesla 账户",
                isPresented: $showingUnbindConfirm,
                titleVisibility: .visible
            ) {
                Button("解绑", role: .destructive) {
                    Task {
                        let result = await authSession.unbindTesla(api: apiService)
                        if case .failure(let err) = result {
                            unbindError = err.localizedDescription
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将清除服务端授权与本地凭据，下次登录需要重新授权 Tesla。")
            }
            .alert("解绑失败", isPresented: Binding(
                get: { unbindError != nil },
                set: { if !$0 { unbindError = nil } }
            )) {
                Button("好") { unbindError = nil }
            } message: {
                Text(unbindError ?? "")
            }
        }
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(viewModel.displayName ?? "我的 Tesla")
                    .font(.headline)
                Spacer()
                stateBadge
            }
            HStack(spacing: 16) {
                Label {
                    Text("\(viewModel.batteryLevel ?? 0)%")
                } icon: {
                    Image(systemName: batteryIcon)
                }
                if let range = viewModel.batteryRangeKm {
                    Label("\(Int(range)) km", systemImage: "road.lanes")
                }
                Spacer()
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)

            if let location = viewModel.locationName {
                Label {
                    Text(location).lineLimit(1)
                } icon: {
                    Image(systemName: "location.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var batteryIcon: String {
        let level = viewModel.batteryLevel ?? 0
        switch level {
        case ..<20: return "battery.0"
        case ..<50: return "battery.25"
        case ..<80: return "battery.75"
        default: return "battery.100"
        }
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView().controlSize(.small)
        case .waking(let attempt, let max):
            Label("唤醒中 \(attempt)/\(max)", systemImage: "moon.zzz")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        case .ready:
            Label(chargingLabel, systemImage: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        case .offline:
            Label("离线", systemImage: "circle.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.gray)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    private var chargingLabel: String {
        switch viewModel.chargingState {
        case "Charging": return "充电中"
        case "Complete": return "充电完成"
        case "Disconnected": return "在线"
        default: return "在线"
        }
    }
}
