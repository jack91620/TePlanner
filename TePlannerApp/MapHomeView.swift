import SwiftUI
import TePlannerKit
import MAMapKit

/// 充电规划子页：以高德地图为主体的车辆位置 + 沿途充电站可视化。
/// 不再是顶级页面 —— 由 HubView push 进来，所以 HomeViewModel /
/// AutomationEngine 都从父级注入而不是自己 own，避免上下浮动时丢状态。
/// Polling、车辆状态观察、本地通知 wiring 都搬到 HubView 里去做。
///
/// 路线规划状态机直接挂在这个 View 上 —— 没有再额外的 modal sheet。
/// 用户从搜索 / 充电站详情里选了目的地后，drawer 自己进 .loading →
/// .loaded，旧的 RoutePreviewView 已经删掉。
struct MapHomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    private let apiService: APIServiceProtocol
    @State private var showingSearch = false
    @State private var pendingStation: ChargingStation?
    @State private var routeState: RouteState = .empty
    @State private var recenterToken: Int = 0
    @State private var showingPlanningSettings = false
    private let alongRoutePOIService = AlongRoutePOIService()

    enum RouteState {
        case empty
        case loading(POIResult)
        case loaded(RoutePlanResponse)
        case error(POIResult, String)

        var loadedPlan: RoutePlanResponse? {
            if case .loaded(let plan) = self { return plan }
            return nil
        }
    }

    init(
        apiService: APIServiceProtocol,
        viewModel: HomeViewModel
    ) {
        self.apiService = apiService
        self.viewModel = viewModel
    }

    var body: some View {
        ZStack(alignment: .top) {
            AMapVehicleMapView(
                coordinate: viewModel.coordinate.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                vehicleTitle: viewModel.displayName ?? "我的 Tesla",
                batteryLevel: viewModel.batteryLevel,
                route: routeState.loadedPlan,
                recenterToken: recenterToken
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    recenterButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 240)
                }
            }
        }
        .navigationTitle("充电规划")
        .navigationBarTitleDisplayMode(.inline)
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
                    if routeState.loadedPlan != nil {
                        Button("清除路线", systemImage: "xmark.circle") {
                            routeState = .empty
                        }
                    }
                    Divider()
                    Button("路线设置", systemImage: "slider.horizontal.3") {
                        showingPlanningSettings = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("map_menu_button")
            }
        }
        .sheet(isPresented: $showingPlanningSettings) {
            RoutePlanningSettingsSheet()
        }
        .sheet(isPresented: .constant(true)) {
            HomeBottomSheet(
                mode: drawerMode,
                apiService: apiService,
                coordinate: viewModel.coordinate,
                vehicleId: viewModel.vehicle?.id,
                onSelectStation: { station in
                    pendingStation = station
                },
                onSelectTrip: { trip in
                    Log.app.notice("recent trip tapped: id=\(trip.id, privacy: .public)")
                    if let lat = trip.destination.lat, let lng = trip.destination.lng {
                        startRouteLoad(POIResult(
                            id: "trip-\(trip.id)",
                            name: trip.destination.address ?? "目的地",
                            address: trip.destination.address ?? "",
                            latitude: lat,
                            longitude: lng
                        ))
                    }
                },
                onClearRoute: {
                    routeState = .empty
                }
            )
            .presentationDetents([.height(220), .medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
            .sheet(isPresented: $showingSearch) {
                SearchView(service: AMapPOISearchService()) { result in
                    Log.app.notice("destination picked: \(result.name, privacy: .public) (\(result.latitude), \(result.longitude))")
                    startRouteLoad(result)
                }
            }
            .sheet(item: $pendingStation) { station in
                ChargingStationDetailView(station: station) { picked in
                    startRouteLoad(POIResult(
                        id: picked.id,
                        name: picked.name,
                        address: picked.address ?? "",
                        latitude: picked.latitude,
                        longitude: picked.longitude
                    ))
                }
            }
        }
    }

    private var drawerMode: HomeBottomSheet.Mode {
        switch routeState {
        case .empty:
            return .tabs
        case .loading:
            return .loading
        case .loaded(let plan):
            return .loaded(plan)
        case .error(let dest, let message):
            return .error(message, retry: { startRouteLoad(dest) })
        }
    }

    private func startRouteLoad(_ destination: POIResult) {
        routeState = .loading(destination)
        Task { await loadRoute(destination) }
    }

    private func loadRoute(_ destination: POIResult) async {
        let origin = viewModel.coordinate.map {
            LocationInput(latitude: $0.latitude, longitude: $0.longitude, address: nil)
        }
        let vm = RoutePreviewViewModel(
            apiService: apiService,
            poiProvider: alongRoutePOIService,
            destination: destination,
            origin: origin,
            currentSoc: viewModel.batteryLevel,
            vehicleId: viewModel.vehicle?.id
        )
        await vm.load()
        // The user could have cleared / replaced the destination while
        // the load was in flight — only commit the result if we're still
        // loading this exact destination.
        guard case .loading(let active) = routeState, active.id == destination.id else { return }
        switch vm.state {
        case .loaded(let plan):
            routeState = .loaded(plan)
        case .error(let message):
            routeState = .error(destination, message)
        case .loading:
            break
        }
    }

    private var recenterButton: some View {
        Button {
            recenterToken &+= 1
        } label: {
            Image(systemName: routeState.loadedPlan == nil ? "location.fill" : "arrow.up.left.and.arrow.down.right")
                .font(.title3)
                .foregroundStyle(.primary)
                .padding(10)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
        .accessibilityIdentifier("recenter_button")
        .accessibilityLabel(routeState.loadedPlan == nil ? "居中到车辆" : "适配整段路线")
    }
}
