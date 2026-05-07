import Foundation

/// Watches the iOS polling loop's `VehicleState` snapshots and
/// records charging sessions to a `ChargingSessionStore`. Hooked
/// up by HubView in the same `.onChange(viewModel.vehicleState)`
/// callback that drives the AutomationEngine.
///
/// State machine:
///
///   Disconnected/Stopped/nil ──Charging──▶  open new session
///   Charging                  ──Complete/Disconnected─▶  finalize current
///
/// We deliberately keep this orthogonal to AutomationEngine —
/// the engine's contract is "evaluate context → emit alert," and
/// recording sessions is a side effect that doesn't belong on that
/// path. Running them in parallel from the same observer is simpler
/// than overloading either.
@MainActor
public final class ChargingSessionTracker {
    private let store: ChargingSessionStore
    private let now: () -> Date
    private var lastSeenChargingState: String?

    public init(
        store: ChargingSessionStore = UserDefaultsChargingSessionStore.shared,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.now = now
    }

    public func observe(_ state: VehicleState?, locationName: String? = nil) {
        guard let state else { return }
        let current = state.chargingState
        defer { lastSeenChargingState = current }

        let wasCharging = (lastSeenChargingState == "Charging")
        let isCharging = (current == "Charging")

        if !wasCharging && isCharging {
            beginSession(state: state, locationName: locationName)
        } else if wasCharging && !isCharging {
            endSession(state: state, finalState: current)
        }
    }

    private func beginSession(state: VehicleState, locationName: String?) {
        // Defensive — if some prior crash left a session ongoing,
        // close it out as "incomplete" before opening a new one.
        if var stale = store.ongoing() {
            stale.endAt = now()
            stale.endedAsComplete = false
            store.upsert(stale)
            Log.vehicle.notice("charging-session: closed stale ongoing session before opening new one")
        }

        let session = ChargingSession(
            vehicleId: state.vehicleId,
            startAt: now(),
            startSoc: state.batteryLevel,
            startRangeKm: state.batteryRange,
            locationName: locationName
        )
        store.upsert(session)
        Log.vehicle.notice("charging-session: started (soc=\(state.batteryLevel ?? -1, privacy: .public))")
    }

    private func endSession(state: VehicleState, finalState: String?) {
        guard var ongoing = store.ongoing() else {
            // Started in this app session means we have a record;
            // started before app launch means we missed the open
            // event and there's nothing to finalize. Skip silently.
            return
        }
        ongoing.endAt = now()
        ongoing.endSoc = state.batteryLevel
        ongoing.endRangeKm = state.batteryRange
        ongoing.endedAsComplete = (finalState == "Complete")
        store.upsert(ongoing)
        Log.vehicle.notice("charging-session: ended (final=\(finalState ?? "?", privacy: .public), socΔ=\(ongoing.socDelta ?? -1, privacy: .public))")
    }
}
