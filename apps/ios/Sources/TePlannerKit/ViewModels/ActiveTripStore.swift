import Combine
import Foundation

/// Backs the Hub "进行中行程" card and exposes the advance / replan /
/// cancel mutations. Single source of truth for the user's currently
/// in-flight multi-stop nav.
///
/// Lifecycle:
/// - Hub calls `refresh()` on appear and after returning from background
/// - `start(...)` is called by RoutePreviewViewModel after a route plan
///   loads + user taps "发到车"
/// - `advance()` fires on the Hub card's "下一段" button
/// - `cancel()` from the Hub card menu
@MainActor
public final class ActiveTripStore: ObservableObject {
    @Published public private(set) var trip: ActiveTrip?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String?

    private let apiService: APIServiceProtocol

    public init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        switch await apiService.fetchActiveTrip() {
        case .success(let t):
            trip = t
            lastError = nil
        case .failure(let err):
            lastError = err.localizedDescription
        }
    }

    /// Kick off a new trip. Cancels any existing one server-side.
    @discardableResult
    public func start(
        vehicleId: String,
        stops: [TripStop],
        polyline: [[Double]]? = nil,
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        let request = StartTripRequest(
            vehicleId: vehicleId, stops: stops, polyline: polyline,
        )
        switch await apiService.startTrip(request) {
        case .success(let t):
            trip = t
            lastError = nil
            return true
        case .failure(let err):
            lastError = err.localizedDescription
            return false
        }
    }

    /// Push the next planned stop to the car. No-op if we're already
    /// on the final stop (server marks the trip completed).
    public func advance() async {
        guard let id = trip?.id else { return }
        isLoading = true
        defer { isLoading = false }
        switch await apiService.advanceTrip(id) {
        case .success(let t):
            trip = (t.status == .active) ? t : nil
            lastError = nil
        case .failure(let err):
            lastError = err.localizedDescription
        }
    }

    public func replan(
        newStops: [TripStop],
        reason: String,
        polyline: [[Double]]? = nil,
    ) async {
        guard let id = trip?.id else { return }
        isLoading = true
        defer { isLoading = false }
        let request = ReplanTripRequest(
            newStops: newStops, reason: reason, polyline: polyline,
        )
        switch await apiService.replanTrip(id, request: request) {
        case .success(let t):
            trip = t
            lastError = nil
        case .failure(let err):
            lastError = err.localizedDescription
        }
    }

    public func cancel() async {
        guard let id = trip?.id else { return }
        isLoading = true
        defer { isLoading = false }
        switch await apiService.cancelTrip(id) {
        case .success:
            trip = nil
            lastError = nil
        case .failure(let err):
            lastError = err.localizedDescription
        }
    }
}
