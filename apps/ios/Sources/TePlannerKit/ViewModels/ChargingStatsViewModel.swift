import Foundation
import Combine

/// Drives `ChargingStatsView`. Pulls sessions from the store on
/// `refresh()` (called from `.task`) and exposes month-bucketed
/// aggregates as computed properties so SwiftUI redraws cleanly when
/// `sessions` updates.
@MainActor
public final class ChargingStatsViewModel: ObservableObject {
    @Published public private(set) var sessions: [ChargingSession] = []

    private let store: ChargingSessionStore
    private let now: () -> Date
    private let calendar: Calendar

    public init(
        store: ChargingSessionStore = UserDefaultsChargingSessionStore.shared,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.now = now
        self.calendar = calendar
    }

    public func refresh() {
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
