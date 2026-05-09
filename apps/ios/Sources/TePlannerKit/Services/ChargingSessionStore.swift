import Combine
import Foundation

/// Persistence + retrieval of `ChargingSession` records. Phase D.4
/// swap: backend (`charging_session` table + Phase A.4 endpoints) is
/// now the system of record. `BackendChargingSessionStore` keeps a
/// local in-memory cache so `recent / ongoing` stay synchronous (the
/// tracker observes vehicle-state poll ticks at sub-second cadence
/// and can't afford a network round-trip there); `upsert` is fire-
/// and-forget — cache updates immediately, the POST runs in a
/// detached Task, and `changesPublisher` emits when the server
/// response lands so the UI re-renders.
@MainActor
public protocol ChargingSessionStore: AnyObject {
    /// Returns sessions newest-first. `limit == nil` means unbounded.
    /// Synchronous read from the cache.
    func recent(limit: Int?) -> [ChargingSession]
    /// Currently-active (no endAt) session if any. There can only be
    /// one at a time — the tracker enforces that invariant.
    func ongoing() -> ChargingSession?
    /// Add or update a session. Existing record with the same id is
    /// overwritten so callers can use this for both create + finalize.
    /// In the backend-backed implementation, the cache mutates
    /// synchronously and the POST is fire-and-forget; on failure the
    /// cache reverts and `changesPublisher` re-emits.
    func upsert(_ session: ChargingSession)
    /// Remove all stored sessions. Used by tests + the "reset stats"
    /// UI knob.
    func clear()
    /// Pull canonical state from the server. Idempotent; safe to call
    /// on every app foreground / vehicle binding change.
    func refresh(vehicleId: String?) async
    /// Fires whenever the cache changes. UI subscribes via .onReceive.
    var changesPublisher: AnyPublisher<Void, Never> { get }
}

/// Backend-backed implementation. Tracker observes the polling loop
/// and calls `upsert` synchronously; the cache mutates immediately so
/// HubView's stats card and the ongoing-session detection see fresh
/// state, while the POST flies in the background. On API failure the
/// cache rolls back to the prior shape and `changesPublisher` fires
/// so SwiftUI re-renders the corrected state.
@MainActor
public final class BackendChargingSessionStore: ChargingSessionStore, ObservableObject {
    @Published private var sessions: [ChargingSession] = []
    private let apiService: APIServiceProtocol
    private let changesSubject = PassthroughSubject<Void, Never>()

    public init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }

    public var changesPublisher: AnyPublisher<Void, Never> {
        changesSubject.eraseToAnyPublisher()
    }

    public func recent(limit: Int?) -> [ChargingSession] {
        let sorted = sessions.sorted { $0.startAt > $1.startAt }
        if let limit { return Array(sorted.prefix(limit)) }
        return sorted
    }

    public func ongoing() -> ChargingSession? {
        sessions.first(where: { $0.isOngoing })
    }

    public func upsert(_ session: ChargingSession) {
        let priorIdx = sessions.firstIndex(where: { $0.id == session.id })
        let prior = priorIdx.map { sessions[$0] }
        if let idx = priorIdx {
            sessions[idx] = session
        } else {
            sessions.append(session)
        }
        changesSubject.send(())
        guard let vehicleId = session.vehicleId, !vehicleId.isEmpty else {
            // No vehicle — keep cache local; nothing to send.
            return
        }
        Task { [apiService, weak self] in
            let result = await apiService.upsertChargingSession(
                vehicleId: vehicleId,
                request: session.toAPIRequest(),
            )
            guard let self else { return }
            switch result {
            case .success(let response):
                // Server may return an authoritative ended_at /
                // soc / range computation; merge anything new it
                // sent back into the cache so duration / range
                // additions stay consistent with future GETs.
                if let idx = self.sessions.firstIndex(where: { $0.id == session.id }) {
                    self.sessions[idx] = response.toDomain(localId: session.id)
                    self.changesSubject.send(())
                }
            case .failure(let err):
                Log.api.error("charging-session upsert failed: \(err.localizedDescription, privacy: .public)")
                if let prior, let idx = self.sessions.firstIndex(where: { $0.id == session.id }) {
                    self.sessions[idx] = prior
                } else if prior == nil {
                    self.sessions.removeAll { $0.id == session.id }
                }
                self.changesSubject.send(())
            }
        }
    }

    public func clear() {
        sessions.removeAll()
        changesSubject.send(())
        // Backend clear isn't an exposed endpoint — local-only reset.
    }

    public func refresh(vehicleId: String?) async {
        guard let vehicleId, !vehicleId.isEmpty else { return }
        let result = await apiService.listChargingSessions(vehicleId: vehicleId, limit: 100)
        switch result {
        case .success(let response):
            sessions = response.sessions.map { $0.toDomain() }
            changesSubject.send(())
        case .failure(let err):
            Log.api.error("charging-session refresh failed: \(err.localizedDescription, privacy: .public)")
        }
    }
}

/// Test double — pure cache, no network. `refresh` is a no-op so
/// existing tracker tests continue to assert on synchronous upsert.
@MainActor
public final class InMemoryChargingSessionStore: ChargingSessionStore, ObservableObject {
    @Published private var sessions: [ChargingSession] = []
    private let changesSubject = PassthroughSubject<Void, Never>()

    public init() {}

    public var changesPublisher: AnyPublisher<Void, Never> {
        changesSubject.eraseToAnyPublisher()
    }

    public func recent(limit: Int?) -> [ChargingSession] {
        let sorted = sessions.sorted { $0.startAt > $1.startAt }
        if let limit { return Array(sorted.prefix(limit)) }
        return sorted
    }
    public func ongoing() -> ChargingSession? {
        sessions.first(where: { $0.isOngoing })
    }
    public func upsert(_ session: ChargingSession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        } else {
            sessions.append(session)
        }
        changesSubject.send(())
    }
    public func clear() {
        sessions.removeAll()
        changesSubject.send(())
    }
    public func refresh(vehicleId: String?) async {}
}
