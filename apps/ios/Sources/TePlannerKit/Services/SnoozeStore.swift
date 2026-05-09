import Combine
import Foundation

/// Phase D.1 — single source of truth for active snoozes on the iOS
/// client. Replaces `SettingsStore.ruleSnooze` (UserDefaults JSON).
///
/// Behavior:
///   - Backend is canonical; iOS keeps an in-memory `[String: Date]`
///     cache for fast UI reads (HubView, AutomationsListView,
///     AutomationEngine snooze gate).
///   - On launch, `refresh()` populates the cache from
///     `GET /automations/snoozes` (server already filters out expired
///     rows).
///   - `snooze(...)` and `unsnooze(...)` apply optimistic updates so
///     the UI reflects the action immediately, then await the API call
///     and roll back on failure.
///
/// Engine and views observe the published `activeUntil` map to stay
/// reactive; the @MainActor isolation matches AutomationEngine.
@MainActor
public protocol SnoozeStore: AnyObject {
    /// rule_id → server-acknowledged snooze deadline (UTC). Filtered to
    /// `> now` on every read so the engine never sees stale entries.
    var activeUntil: [String: Date] { get }

    /// Publisher fires whenever `activeUntil` changes (refresh, snooze,
    /// unsnooze). Engine subscribes to recompute alerts on change.
    var changesPublisher: AnyPublisher<Void, Never> { get }

    /// Pull the current server state. Idempotent; safe to call on every
    /// app foreground.
    func refresh() async

    /// Snooze ``ruleId`` for ``hours`` from now. Optimistic — the local
    /// cache updates first, the API call follows; on failure the cache
    /// reverts and the error is logged. Returns `true` if the server
    /// accepted the request.
    @discardableResult
    func snooze(ruleId: String, hours: Double, reason: String?) async -> Bool

    /// Snooze ``ruleId`` until an absolute UTC time.
    @discardableResult
    func snooze(ruleId: String, until: Date, reason: String?) async -> Bool

    /// Clear any active snooze on ``ruleId``. Idempotent — server
    /// returns success even if no row existed.
    @discardableResult
    func unsnooze(ruleId: String) async -> Bool
}


/// Backend-backed implementation. UI + engine read from the cache;
/// writes round-trip through APIService and update the cache on
/// completion.
@MainActor
public final class BackendSnoozeStore: SnoozeStore, ObservableObject {
    @Published private var snoozes: [String: Date] = [:]
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

    public var activeUntil: [String: Date] {
        let cutoff = now()
        return snoozes.filter { $0.value > cutoff }
    }

    public var changesPublisher: AnyPublisher<Void, Never> {
        changesSubject.eraseToAnyPublisher()
    }

    public func refresh() async {
        let result = await apiService.fetchSnoozes()
        switch result {
        case .success(let response):
            var fresh: [String: Date] = [:]
            for s in response.snoozes {
                fresh[s.ruleId] = s.snoozedUntilUtc
            }
            snoozes = fresh
            changesSubject.send(())
        case .failure(let err):
            Log.api.error("snoozes refresh failed: \(err.localizedDescription, privacy: .public)")
        }
    }

    @discardableResult
    public func snooze(ruleId: String, hours: Double, reason: String?) async -> Bool {
        let optimisticUntil = now().addingTimeInterval(hours * 3600)
        return await applyOptimistic(
            ruleId: ruleId,
            until: optimisticUntil,
            apiCall: { [apiService] in
                await apiService.snoozeRule(ruleId: ruleId, hours: hours, until: nil, reason: reason)
            }
        )
    }

    @discardableResult
    public func snooze(ruleId: String, until: Date, reason: String?) async -> Bool {
        return await applyOptimistic(
            ruleId: ruleId,
            until: until,
            apiCall: { [apiService] in
                await apiService.snoozeRule(ruleId: ruleId, hours: nil, until: until, reason: reason)
            }
        )
    }

    @discardableResult
    public func unsnooze(ruleId: String) async -> Bool {
        let previous = snoozes[ruleId]
        snoozes.removeValue(forKey: ruleId)
        changesSubject.send(())
        let result = await apiService.unsnoozeRule(ruleId: ruleId)
        switch result {
        case .success:
            return true
        case .failure(let err):
            Log.api.error("unsnooze failed for \(ruleId, privacy: .public): \(err.localizedDescription, privacy: .public)")
            if let previous {
                snoozes[ruleId] = previous
                changesSubject.send(())
            }
            return false
        }
    }

    private func applyOptimistic(
        ruleId: String,
        until: Date,
        apiCall: () async -> Result<SnoozeRecord, APIError>
    ) async -> Bool {
        let previous = snoozes[ruleId]
        snoozes[ruleId] = until
        changesSubject.send(())
        let result = await apiCall()
        switch result {
        case .success(let record):
            snoozes[ruleId] = record.snoozedUntilUtc
            changesSubject.send(())
            return true
        case .failure(let err):
            Log.api.error("snooze failed for \(ruleId, privacy: .public): \(err.localizedDescription, privacy: .public)")
            if let previous {
                snoozes[ruleId] = previous
            } else {
                snoozes.removeValue(forKey: ruleId)
            }
            changesSubject.send(())
            return false
        }
    }
}


/// Pure in-memory store for tests + previews. No backend coupling.
@MainActor
public final class InMemorySnoozeStore: SnoozeStore, ObservableObject {
    @Published private var snoozes: [String: Date] = [:]
    private let now: () -> Date
    private let changesSubject = PassthroughSubject<Void, Never>()

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    public var activeUntil: [String: Date] {
        let cutoff = now()
        return snoozes.filter { $0.value > cutoff }
    }

    public var changesPublisher: AnyPublisher<Void, Never> {
        changesSubject.eraseToAnyPublisher()
    }

    public func refresh() async {}

    @discardableResult
    public func snooze(ruleId: String, hours: Double, reason: String?) async -> Bool {
        snoozes[ruleId] = now().addingTimeInterval(hours * 3600)
        changesSubject.send(())
        return true
    }

    @discardableResult
    public func snooze(ruleId: String, until: Date, reason: String?) async -> Bool {
        snoozes[ruleId] = until
        changesSubject.send(())
        return true
    }

    @discardableResult
    public func unsnooze(ruleId: String) async -> Bool {
        snoozes.removeValue(forKey: ruleId)
        changesSubject.send(())
        return true
    }

    /// Test helper — pre-seed the cache without going through the
    /// async API path.
    public func _setForTesting(_ entries: [String: Date]) {
        snoozes = entries
        changesSubject.send(())
    }
}
