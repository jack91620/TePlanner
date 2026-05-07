import SwiftUI
import TePlannerKit
import MAMapKit

/// 充电规划子页：以高德地图为主体的车辆位置 + 沿途充电站可视化。
/// 不再是顶级页面 —— 由 HubView push 进来，所以 HomeViewModel /
/// AutomationEngine 都从父级注入而不是自己 own，避免上下浮动时丢状态。
/// Polling、车辆状态观察、本地通知 wiring 都搬到 HubView 里去做。
struct MapHomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    private let apiService: APIServiceProtocol
    @State private var showingSearch = false
    @State private var pendingDestination: POIResult?
    @State private var pendingStation: ChargingStation?
    @State private var currentRoute: RoutePlanResponse?
    @State private var recenterToken: Int = 0
    @State private var showingPlanningSettings = false
    private let alongRoutePOIService = AlongRoutePOIService()

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
                route: currentRoute,
                recenterToken: recenterToken
            )
            .ignoresSafeArea()

            // 顶部状态卡 + 提醒条都已经在 Hub 显示，这里不再重复——
            // 充电规划场景下用户的注意力应该在地图 + 搜索 + 路线上，
            // 不在车辆元信息。
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
                    if currentRoute != nil {
                        Button("清除路线", systemImage: "xmark.circle") {
                            currentRoute = nil
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
                apiService: apiService,
                coordinate: viewModel.coordinate,
                activeRoute: currentRoute,
                vehicleId: viewModel.vehicle?.id,
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
                },
                onClearRoute: {
                    currentRoute = nil
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
                    poiProvider: alongRoutePOIService,
                    destination: destination,
                    origin: viewModel.coordinate.map {
                        LocationInput(latitude: $0.latitude, longitude: $0.longitude, address: nil)
                    },
                    currentSoc: viewModel.batteryLevel,
                    vehicleId: viewModel.vehicle?.id,
                    onPlanLoaded: { plan in currentRoute = plan }
                )
            }
        }
    }

    private var recenterButton: some View {
        Button {
            recenterToken &+= 1
        } label: {
            Image(systemName: currentRoute == nil ? "location.fill" : "arrow.up.left.and.arrow.down.right")
                .font(.title3)
                .foregroundStyle(.primary)
                .padding(10)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
        .accessibilityIdentifier("recenter_button")
        .accessibilityLabel(currentRoute == nil ? "居中到车辆" : "适配整段路线")
    }

}
