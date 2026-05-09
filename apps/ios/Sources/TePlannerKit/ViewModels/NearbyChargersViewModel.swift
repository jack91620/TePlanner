import Foundation

/// Drives the "附近" tab — a list of charging stations near a given
/// coordinate (typically the vehicle's), with an optional type filter
/// (supercharger / destination / CCS / CHAdeMO / 国标). The backend
/// proxies AMap/Tencent searches so heavy lifting stays server-side.
@MainActor
public final class NearbyChargersViewModel: ObservableObject {
    public enum State: Equatable {
        case idle
        case loading
        case loaded([ChargingStation])
        case empty
        case error(String)
    }

    @Published public private(set) var state: State = .idle
    @Published public var selectedType: ChargingStationType?
    @Published public var radiusKm: Int = 30

    private let apiService: APIServiceProtocol

    public init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }

    /// Fetch chargers around `coordinate`. Re-running with a different
    /// `selectedType` or `radiusKm` is the contract for "filter
    /// changed" — the view binds those to controls.
    public func load(near coordinate: (latitude: Double, longitude: Double)?) async {
        guard let coordinate else {
            state = .error("无法获取车辆位置")
            return
        }
        state = .loading
        Log.search.notice("nearby chargers (lat=\(coordinate.latitude, privacy: .public), lng=\(coordinate.longitude, privacy: .public), r=\(self.radiusKm, privacy: .public)km, type=\(self.selectedType?.rawValue ?? "all", privacy: .public))")

        let result = await apiService.getNearbyStations(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusKm: radiusKm,
            type: selectedType?.rawValue
        )
        switch result {
        case .success(let stations):
            Log.search.notice("nearby chargers ok (count=\(stations.count, privacy: .public))")
            state = stations.isEmpty ? .empty : .loaded(stations)
        case .failure(let error):
            Log.search.error("nearby chargers failed: \(error.localizedDescription, privacy: .public)")
            state = .error(error.localizedDescription)
        }
    }
}
