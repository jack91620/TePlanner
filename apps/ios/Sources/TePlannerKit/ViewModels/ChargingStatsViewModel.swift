import Foundation
import Combine

/// Drives `ChargingStatsView`. Phase D.4 — sessions come from a
/// shared `ChargingSessionStore` (typically `BackendChargingSessionStore`)
/// rather than a private UserDefaults blob; the store maintains the
/// canonical cache and the view-model just projects it.
@MainActor
public final class ChargingStatsViewModel: ObservableObject {
    @Published public private(set) var sessions: [ChargingSession] = []

    private let store: ChargingSessionStore
    private let now: () -> Date
    private let calendar: Calendar
    private var cancellables = Set<AnyCancellable>()

    public init(
        store: ChargingSessionStore,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.now = now
        self.calendar = calendar
        store.changesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.reload() }
            .store(in: &cancellables)
        reload()
    }

    public func refresh(vehicleId: String? = nil) async {
        await store.refresh(vehicleId: vehicleId)
        reload()
    }

    /// Sync re-pull from the cache. Tests use this to assert
    /// deterministically after seeding the store; production code goes
    /// through `refresh(vehicleId:)` (async, hits backend) or relies
    /// on the `changesPublisher` subscription to keep UI in sync.
    public func reload() {
        sessions = store.recent(limit: 100)
    }

    // MARK: - month-bucket aggregates

    public var monthlyCount: Int { thisMonthSessions.count }

    public var monthlyDurationMinutes: Int {
        thisMonthSessions.compactMap(\.durationMinutes).reduce(0, +)
    }

    public var monthlyRangeAddedKm: Double {
        thisMonthSessions.compactMap(\.rangeAddedKm).reduce(0, +)
    }

    public var monthlySocDelta: Int {
        thisMonthSessions.compactMap(\.socDelta).reduce(0, +)
    }

    /// `nil` ⇒ no data; UI uses this to drive the empty-state view.
    public var hasAnyData: Bool { !sessions.isEmpty }

    // MARK: - data availability flags
    //
    // Server-side closer (charge_analysis/closer.py) often closes
    // a session without end_soc / end_range_km because telemetry
    // was stale at close time. The session is correctly marked as
    // 中断 but the UI used to display "0 km" / "0%" which read as
    // "I charged but added nothing." These flags let the cards
    // distinguish "no data captured" from "true zero."

    /// At least one finalized session this month has both start+end SOC.
    public var hasMonthlySocData: Bool {
        thisMonthSessions.contains { $0.socDelta != nil }
    }

    /// At least one finalized session this month has both start+end range.
    public var hasMonthlyRangeData: Bool {
        thisMonthSessions.contains { $0.rangeAddedKm != nil }
    }

    // MARK: - private

    private var thisMonthSessions: [ChargingSession] {
        let monthStart = startOfMonth(now())
        // Only count finalized sessions in monthly aggregates so the
        // numbers don't tick up while a session is still ongoing.
        return sessions.filter { $0.startAt >= monthStart && !$0.isOngoing }
    }

    private func startOfMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }
}
