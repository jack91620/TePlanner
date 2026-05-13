import CoreLocation
import Foundation

/// Drives the route preview sheet that appears after the user picks
/// a destination in SearchView.
///
/// Phase 8.2 orchestration: backend no longer does along-route POI
/// search itself (the Web Service `place/around` sampling can't pin
/// stations to actual highways). Instead the VM runs a 3-step flow:
///
/// 1. POST /routes/route → polyline + distance + duration
/// 2. AlongRoutePOIProvider (AMap iOS SDK 沿途搜索) → road-corridor POIs
/// 3. POST /routes/charging-plan with those POIs → greedy charging stops
///
/// Steps merged into `RoutePlanResponse`-shape so downstream UI
/// (RoutePreviewView) doesn't need changes.
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
    private let poiProvider: AlongRoutePOIProvider?
    private let origin: LocationInput?
    private let currentSoc: Int?
    private let vehicleId: String?
    private let commandStatusStore: CommandStatusStore?
    private let onPlanLoaded: ((RoutePlanResponse) -> Void)?

    public init(
        apiService: APIServiceProtocol,
        poiProvider: AlongRoutePOIProvider? = nil,
        destination: POIResult,
        origin: LocationInput?,
        currentSoc: Int?,
        vehicleId: String?,
        commandStatusStore: CommandStatusStore? = nil,
        onPlanLoaded: ((RoutePlanResponse) -> Void)? = nil
    ) {
        self.apiService = apiService
        self.poiProvider = poiProvider
        self.destination = destination
        self.origin = origin
        self.currentSoc = currentSoc
        self.vehicleId = vehicleId
        self.commandStatusStore = commandStatusStore
        self.onPlanLoaded = onPlanLoaded
    }

    /// Fetch the route plan via the 3-step orchestration. Idempotent
    /// — calling twice replaces the state.
    public func load() async {
        state = .loading
        Log.search.notice("plan route to \(self.destination.name, privacy: .public) (lat=\(self.destination.latitude, privacy: .public), lng=\(self.destination.longitude, privacy: .public))")
        // Destination came from AMap POI search → GCJ-02. Project
        // convention: iOS sends WGS-84 to backend; backend converts
        // to GCJ-02 internally before calling AMap Web for routing.
        // Convert at the boundary so the route polyline starts from
        // the correct origin pin, not one offset by ~100 m.
        let destWGS = CoordConverter.gcj02ToWgs84(
            CLLocationCoordinate2D(
                latitude: destination.latitude,
                longitude: destination.longitude,
            ))
        let dest = LocationInput(
            latitude: destWGS.latitude,
            longitude: destWGS.longitude,
            address: destination.address.isEmpty ? destination.name : destination.address
        )
        guard let origin else {
            // No origin = no vehicle position. Without it /routes/route
            // can't compute a polyline, so fail-fast with a clear message.
            state = .error("无法获取车辆位置")
            return
        }

        // Step 1: route metadata
        let routeResult = await apiService.routeOnly(origin: origin, destination: dest)
        let route: RouteOnlyResponse
        switch routeResult {
        case .success(let r): route = r
        case .failure(let err):
            Log.search.error("route fetch failed: \(err.localizedDescription, privacy: .public)")
            state = .error(err.localizedDescription)
            return
        }

        // Step 2: along-route POI (iOS SDK). nil provider = treat as
        // empty — backend will return a fail-fast warning rather than
        // silently sample.
        var pois: [AlongRoutePOI] = []
        if let poiProvider {
            do {
                pois = try await poiProvider.searchChargingStations(polyline: route.polyline)
                Log.search.notice("alongby SDK returned \(pois.count, privacy: .public) POIs")
            } catch {
                Log.search.error("alongby SDK failed: \(error.localizedDescription, privacy: .public)")
                state = .error("沿途充电站搜索失败：\(error.localizedDescription)")
                return
            }
        }

        // Step 3: greedy charging plan
        let planRequest = ChargingPlanRequest(
            polyline: route.polyline.map { [$0.latitude, $0.longitude] },
            totalDistanceKm: route.totalDistanceKm,
            candidatePois: pois,
            initialSoc: currentSoc ?? 80,
            minArrivalSoc: 20
        )
        let planResult = await apiService.chargingPlan(planRequest)
        let plan: ChargingPlanResponse
        switch planResult {
        case .success(let p): plan = p
        case .failure(let err):
            Log.search.error("charging-plan failed: \(err.localizedDescription, privacy: .public)")
            state = .error(err.localizedDescription)
            return
        }

        // Merge into RoutePlanResponse-shape for the existing UI.
        let merged = RoutePlanResponse(
            routeId: nil,
            origin: route.origin,
            destination: route.destination,
            totalDistanceKm: route.totalDistanceKm,
            totalDurationMinutes: route.drivingDurationMinutes + plan.chargingDurationMinutes,
            drivingDurationMinutes: route.drivingDurationMinutes,
            chargingDurationMinutes: plan.chargingDurationMinutes,
            chargingStops: plan.chargingStops,
            numChargingStops: plan.numChargingStops,
            initialSoc: currentSoc ?? 80,
            arrivalSoc: plan.arrivalSoc,
            polyline: route.polyline,
            warnings: plan.warnings
        )
        Log.search.notice("plan ok (stops=\(merged.numChargingStops, privacy: .public), \(merged.totalDistanceKm, privacy: .public) km)")
        state = .loaded(merged)
        onPlanLoaded?(merged)
    }

    /// Push the planned trip (charging stops + final destination) to
    /// the bound vehicle as a sequential nav trip. Backend takes the
    /// stops list, persists an active_trip row, and immediately sends
    /// stops[0] to the car via navigation_request. Subsequent stops
    /// are sent on user "下一段" tap (phase 1) or auto-advance from
    /// the cron monitor (phase 2).
    ///
    /// Requires `vehicleId` and a loaded plan with at least the final
    /// destination. Charging stops between origin and destination are
    /// taken from the merged RoutePlanResponse.chargingStops.
    public func sendToVehicle() async {
        guard let vehicleId else {
            sendState = .failed("未选择车辆")
            return
        }
        guard case .loaded(let plan) = state else {
            sendState = .failed("路线规划未完成")
            return
        }
        sendState = .sending

        let stops = buildTripStops(plan: plan)
        let polyline: [[Double]]? = plan.polyline.isEmpty
            ? nil
            : plan.polyline.map { [$0.latitude, $0.longitude] }
        let request = StartTripRequest(
            vehicleId: vehicleId, stops: stops, polyline: polyline,
        )
        let result = await apiService.startTrip(request)
        switch result {
        case .success(let trip):
            Log.search.notice("trip started id=\(trip.id, privacy: .public) (\(stops.count, privacy: .public) stops) to \(vehicleId, privacy: .public)")
            sendState = .sent
            if let store = commandStatusStore {
                Task { await store.pollUntilSettled() }
            }
            Task { await persistToHistory() }
        case .failure(let error):
            Log.search.error("start trip failed: \(error.localizedDescription, privacy: .public)")
            sendState = .failed(error.localizedDescription)
        }
    }

    /// Build the trip's stop list from the loaded plan: each
    /// `ChargingStop` becomes a `.charging` TripStop in order, then
    /// the user's chosen destination is appended as the `.final` stop.
    /// Coordinates are converted GCJ-02 → WGS-84 at the outbound
    /// boundary (matches the legacy single-destination send path).
    private func buildTripStops(plan: RoutePlanResponse) -> [TripStop] {
        var stops: [TripStop] = []
        for stop in plan.chargingStops {
            let wgs = CoordConverter.gcj02ToWgs84(
                CLLocationCoordinate2D(
                    latitude: stop.latitude, longitude: stop.longitude,
                ))
            stops.append(TripStop(
                latitude: wgs.latitude,
                longitude: wgs.longitude,
                address: stop.address,
                name: stop.name,
                kind: .charging,
                stationId: stop.stationId,
                socTarget: stop.arrivalSoc,
            ))
        }
        let destWgs = CoordConverter.gcj02ToWgs84(
            CLLocationCoordinate2D(
                latitude: destination.latitude,
                longitude: destination.longitude,
            ))
        stops.append(TripStop(
            latitude: destWgs.latitude,
            longitude: destWgs.longitude,
            address: destination.address,
            name: destination.name,
            kind: .final,
        ))
        return stops
    }

    /// POST /routes/save with the loaded plan's origin/dest/totals.
    /// Polyline and charging stops are omitted intentionally for now —
    /// the list view doesn't render them yet, and avoiding the heavy
    /// payload keeps the save call fast. When 最近 grows a detail
    /// view, plumb them through here.
    private func persistToHistory() async {
        guard case .loaded(let plan) = state else { return }
        let originLoc = SaveRoutePlanLocation(
            latitude: plan.origin.lat ?? 0,
            longitude: plan.origin.lng ?? 0,
            address: plan.origin.name,
        )
        let destLoc = SaveRoutePlanLocation(
            latitude: destination.latitude,
            longitude: destination.longitude,
            address: destination.name,
        )
        let body = SaveRoutePlanRequest(
            origin: originLoc,
            destination: destLoc,
            totalDistanceKm: plan.totalDistanceKm,
            totalDurationMinutes: plan.totalDurationMinutes,
        )
        let result = await apiService.saveRoutePlan(body)
        if case .failure(let err) = result {
            Log.search.notice("route save failed (non-fatal): \(err.localizedDescription, privacy: .public)")
        }
    }
}
