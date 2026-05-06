import Foundation

/// Drives the route preview sheet that appears after the user picks a
/// destination in SearchView. On init it fires the backend route plan
/// (origin = current vehicle coordinate, destination = picked POI) and
/// exposes a state machine the view consumes; the user can then push
/// the plan to the car via "send to vehicle".
@MainActor
public final class RoutePreviewViewModel: ObservableObject {
    public enum State: Equatable {
        case loading
        case loaded(RoutePlanResponse)
        case error(String)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.loaded(let a), .loaded(let b)): return a.routeId == b.routeId
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    public enum SendState: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    @Published public private(set) var state: State = .loading
    @Published public private(set) var sendState: SendState = .idle

    public let destination: POIResult

    private let apiService: APIServiceProtocol
    private let origin: LocationInput?
    private let currentSoc: Int?
    private let vehicleId: String?
    private let onPlanLoaded: ((RoutePlanResponse) -> Void)?

    public init(
        apiService: APIServiceProtocol,
        destination: POIResult,
        origin: LocationInput?,
        currentSoc: Int?,
        vehicleId: String?,
        onPlanLoaded: ((RoutePlanResponse) -> Void)? = nil
    ) {
        self.apiService = apiService
        self.destination = destination
        self.origin = origin
        self.currentSoc = currentSoc
        self.vehicleId = vehicleId
        self.onPlanLoaded = onPlanLoaded
    }

    /// Fetch the route plan from the backend. Idempotent — calling
    /// twice replaces the state with whatever the latest call resolves.
    public func load() async {
        state = .loading
        Log.search.notice("plan route to \(self.destination.name, privacy: .public) (lat=\(self.destination.latitude, privacy: .public), lng=\(self.destination.longitude, privacy: .public))")
        let dest = LocationInput(
            latitude: destination.latitude,
            longitude: destination.longitude,
            address: destination.address.isEmpty ? destination.name : destination.address
        )
        let result = await apiService.planRoute(
            origin: origin,
            destination: dest,
            currentSoc: currentSoc
        )
        switch result {
        case .success(let plan):
            Log.search.notice("plan ok (route_id=\(plan.routeId ?? -1, privacy: .public), stops=\(plan.numChargingStops, privacy: .public), \(plan.totalDistanceKm, privacy: .public) km)")
            state = .loaded(plan)
            onPlanLoaded?(plan)
        case .failure(let error):
            Log.search.error("plan failed: \(error.localizedDescription, privacy: .public)")
            state = .error(error.localizedDescription)
        }
    }

    /// Push the planned destination to the bound vehicle's nav system.
    /// Requires `vehicleId` — if nil the call is a no-op with an error.
    public func sendToVehicle() async {
        guard let vehicleId else {
            sendState = .failed("未选择车辆")
            return
        }
        sendState = .sending
        let request = NavigationRequest(
            latitude: destination.latitude,
            longitude: destination.longitude,
            name: destination.name
        )
        let result = await apiService.sendNavigation(vehicleId: vehicleId, request: request)
        switch result {
        case .success:
            Log.search.notice("nav sent to \(vehicleId, privacy: .public)")
            sendState = .sent
        case .failure(let error):
            Log.search.error("nav send failed: \(error.localizedDescription, privacy: .public)")
            sendState = .failed(error.localizedDescription)
        }
    }
}
