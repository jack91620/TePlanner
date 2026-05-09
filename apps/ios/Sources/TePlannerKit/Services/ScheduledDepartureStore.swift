import Combine
import Foundation

/// Persistence for the "next departure" schedule. Single-slot — set
/// overwrites previous, clear removes it. Phase D.3 swap: backend
/// (`scheduled_departure` table, /api/v1/user/scheduled-departure)
/// is now the system of record. iOS maintains an in-memory cache that
/// the UI reads synchronously; writes go through the API and update
/// the cache on success.
@MainActor
public protocol ScheduledDepartureStore: AnyObject {
    /// Synchronous read from the cache. Returns nil if the cached
    /// departure has already passed (lazy filter, same as before).
    func current() -> ScheduledDeparture?

    /// Pull the canonical record from the backend on launch / app
    /// foreground. Idempotent.
    func refresh() async

    /// Upsert the departure. Optimistic — cache updates first, the
    /// API call follows; on failure the cache reverts. Returns true
    /// when the server acknowledged the write.
    @discardableResult
    func save(_ departure: ScheduledDeparture) async -> Bool

    /// Clear any active departure. Idempotent server-side.
    @discardableResult
    func clear() async -> Bool

    var changesPublisher: AnyPublisher<Void, Never> { get }
}


/// Backend-backed implementation. UI reads `current()` synchronously
/// from the cache; writes round-trip through APIService.
@MainActor
public final class BackendScheduledDepartureStore: ScheduledDepartureStore, ObservableObject {
    @Published private var cached: ScheduledDeparture?
    private let apiService: APIServiceProtocol
    private let now: () -> Date
    private let changesSubject = PassthroughSubject<Void, Never>()

    public init(
        apiService: APIServiceProtocol,
        now: @escaping () -> Date = Date.init
    ) {
        self.apiService = apiService
        self.now = now
    }

    public var changesPublisher: AnyPublisher<Void, Never> {
        changesSubject.eraseToAnyPublisher()
    }

    public func current() -> ScheduledDeparture? {
        guard let cached, cached.isInFuture(now: now()) else { return nil }
        return cached
    }

    public func refresh() async {
        let result = await apiService.fetchScheduledDeparture()
        switch result {
        case .success(let response):
            cached = response?.toDomain()
            changesSubject.send(())
        case .failure(let err):
            Log.api.error("scheduled-departure refresh failed: \(err.localizedDescription, privacy: .public)")
        }
    }

    @discardableResult
    public func save(_ departure: ScheduledDeparture) async -> Bool {
        let previous = cached
        cached = departure
        changesSubject.send(())
        let result = await apiService.upsertScheduledDeparture(departure)
        switch result {
        case .success(let response):
            cached = response.toDomain()
            changesSubject.send(())
            return true
        case .failure(let err):
            Log.api.error("scheduled-departure save failed: \(err.localizedDescription, privacy: .public)")
            cached = previous
            changesSubject.send(())
            return false
        }
    }

    @discardableResult
    public func clear() async -> Bool {
        let previous = cached
        cached = nil
        changesSubject.send(())
        let result = await apiService.clearScheduledDeparture()
        switch result {
        case .success:
            return true
        case .failure(let err):
            Log.api.error("scheduled-departure clear failed: \(err.localizedDescription, privacy: .public)")
            cached = previous
            changesSubject.send(())
            return false
        }
    }
}


/// Pure in-memory store for tests + previews. No backend coupling.
@MainActor
public final class InMemoryScheduledDepartureStore: ScheduledDepartureStore, ObservableObject {
    @Published private var stored: ScheduledDeparture?
    private let now: () -> Date
    private let changesSubject = PassthroughSubject<Void, Never>()

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    public var changesPublisher: AnyPublisher<Void, Never> {
        changesSubject.eraseToAnyPublisher()
    }

    public func current() -> ScheduledDeparture? {
        guard let stored, stored.isInFuture(now: now()) else {
            self.stored = nil
            return nil
        }
        return stored
    }

    public func refresh() async {}

    @discardableResult
    public func save(_ departure: ScheduledDeparture) async -> Bool {
        stored = departure
        changesSubject.send(())
        return true
    }

    @discardableResult
    public func clear() async -> Bool {
        stored = nil
        changesSubject.send(())
        return true
    }
}
