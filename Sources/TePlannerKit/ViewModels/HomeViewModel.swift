import Foundation
import Combine

/// Drives the home screen: fetch the user's vehicles, pick the primary
/// one, retrieve its current state, and recover from "offline" by sending
/// a wake command and polling.
///
/// Mirrors `HomeViewModel.kt` from the Android app — same retry policy
/// (10 attempts × 3s), same fallback to `.offline` if the vehicle never
/// comes back, same convenience accessors for battery / range /
/// coordinate.
@MainActor
public final class HomeViewModel: ObservableObject {
    public enum State: Equatable {
        case idle
        case loading
        case waking(attempt: Int, maxAttempts: Int)
        case ready
        case offline
        case error(message: String)
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var vehicle: Vehicle?
    @Published public private(set) var vehicleState: VehicleState?

    public var displayName: String? {
        vehicleState?.displayName ?? vehicle?.displayName
    }

    public var batteryLevel: Int? { vehicleState?.batteryLevel }
    public var batteryRangeKm: Double? { vehicleState?.batteryRange }
    public var chargingState: String? { vehicleState?.chargingState }

    public var coordinate: (latitude: Double, longitude: Double)? {
        guard let lat = vehicleState?.latitude, let lon = vehicleState?.longitude else {
            return nil
        }
        return (lat, lon)
    }

    private let apiService: APIServiceProtocol
    private let authSession: AuthSession
    private let maxWakeAttempts: Int
    private let wakeRetryDelay: TimeInterval

    public init(
        apiService: APIServiceProtocol,
        authSession: AuthSession,
        maxWakeAttempts: Int = 10,
        wakeRetryDelay: TimeInterval = 3
    ) {
        self.apiService = apiService
        self.authSession = authSession
        self.maxWakeAttempts = maxWakeAttempts
        self.wakeRetryDelay = wakeRetryDelay
    }

    public func load() async {
        guard let userId = authSession.userId, !userId.isEmpty else {
            Log.vehicle.error("load() called without a logged-in user")
            state = .error(message: "未登录")
            return
        }
        Log.vehicle.notice("load() user=\(userId, privacy: .public)")
        state = .loading

        let vehiclesResult = await apiService.getVehicles(userId: userId)
        switch vehiclesResult {
        case .failure(let error):
            Log.vehicle.error("getVehicles failed: \(error.localizedDescription, privacy: .public)")
            state = .error(message: error.localizedDescription)
        case .success(let response):
            Log.vehicle.notice("got \(response.count, privacy: .public) vehicles")
            guard let vehicle = pickPrimary(from: response.vehicles) else {
                Log.vehicle.error("vehicle list is empty — user has no Tesla bound or backend returned []")
                state = .error(message: "未找到绑定的车辆")
                return
            }
            Log.vehicle.notice("picked vehicle id=\(vehicle.id, privacy: .public) name=\(vehicle.displayName ?? "?", privacy: .public) primary=\(vehicle.isPrimary, privacy: .public)")
            self.vehicle = vehicle
            await fetchVehicleStateWithWake(vehicleId: vehicle.id, userId: userId)
        }
    }

    public func refresh() async {
        guard let vehicleId = vehicle?.id, let userId = authSession.userId else { return }
        await fetchVehicleStateWithWake(vehicleId: vehicleId, userId: userId)
    }

    // MARK: - Internals

    private func pickPrimary(from vehicles: [Vehicle]) -> Vehicle? {
        vehicles.first(where: { $0.isPrimary }) ?? vehicles.first
    }

    private func fetchVehicleStateWithWake(vehicleId: String, userId: String) async {
        if case .success(let fresh) = await apiService.getVehicleState(vehicleId: vehicleId, userId: userId) {
            Log.vehicle.notice("initial state probe succeeded (battery=\(fresh.batteryLevel ?? -1, privacy: .public)%, online=\(fresh.state ?? "?", privacy: .public))")
            self.vehicleState = fresh
            self.state = .ready
            return
        }

        Log.vehicle.notice("vehicle didn't respond, sending wake command")
        state = .waking(attempt: 0, maxAttempts: maxWakeAttempts)
        let wakeResult = await apiService.wakeVehicle(vehicleId: vehicleId, userId: userId)
        if case .success(let resp) = wakeResult {
            Log.vehicle.notice("wake response: state=\(resp.state ?? "?", privacy: .public)")
        } else if case .failure(let err) = wakeResult {
            Log.vehicle.error("wake command failed: \(err.localizedDescription, privacy: .public)")
        }

        for attempt in 1...maxWakeAttempts {
            await sleep(wakeRetryDelay)
            state = .waking(attempt: attempt, maxAttempts: maxWakeAttempts)
            Log.vehicle.debug("wake retry \(attempt, privacy: .public)/\(self.maxWakeAttempts, privacy: .public)")

            if case .success(let fresh) = await apiService.getVehicleState(vehicleId: vehicleId, userId: userId) {
                Log.vehicle.notice("vehicle online after \(attempt, privacy: .public) retries (battery=\(fresh.batteryLevel ?? -1, privacy: .public)%)")
                self.vehicleState = fresh
                self.state = .ready
                return
            }
        }

        Log.vehicle.error("vehicle did not come online after \(self.maxWakeAttempts, privacy: .public) retries — marking offline")
        state = .offline
    }

    private func sleep(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
