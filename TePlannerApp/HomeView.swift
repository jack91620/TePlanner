import SwiftUI
import TePlannerKit
import MAMapKit

/// Phase 1 home screen: AMap centered on the user's primary vehicle,
/// with a battery / range / state header and a refresh button. Offline
/// and waking states surface in the header so the user knows what's
/// going on while the wake-retry loop runs.
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let apiService: APIServiceProtocol
    private let authSession: AuthSession
    @State private var showingSearch = false
    @State private var pendingDestination: POIResult?

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
                batteryLevel: viewModel.batteryLevel
            )
            .ignoresSafeArea()

            statusBar
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("刷新", systemImage: "arrow.clockwise") {
                        Task { await viewModel.refresh() }
                    }
                    Divider()
                    Button("退出登录", systemImage: "arrow.right.square", role: .destructive) {
                        authSession.logout()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            SearchView(service: AMapPOISearchService()) { result in
                Log.app.notice("destination picked: \(result.name, privacy: .public) (\(result.latitude), \(result.longitude))")
                pendingDestination = result
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
                vehicleId: viewModel.vehicle?.id
            )
        }
    }

    private var statusBar: some View {
        VStack(spacing: 6) {
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
