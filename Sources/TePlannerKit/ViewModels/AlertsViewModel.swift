import Foundation

/// Watches a stream of `VehicleState` snapshots and emits
/// `VehicleAlert`s for the "user forgot this is on" cases. The
/// host (HomeView) feeds new states into `observe(_:)` after each
/// poll; alerts are exposed via `@Published alerts` for the pill UI.
///
/// Detection model: when camp_mode (or sentry / overheat / etc. in
/// later slices) flips off→on, record `<kind>StartedAt = now()`. When
/// it flips on→off, clear the timestamp. Each recompute compares
/// duration vs. the user's `SettingsStore` threshold and tags the
/// alert .info or .critical accordingly. The first observation of a
/// state already-on uses `now()` as the start — we under-report
/// duration rather than risk firing critical alerts based on
/// guess-work timestamps.
@MainActor
public final class AlertsViewModel: ObservableObject {
    @Published public private(set) var alerts: [VehicleAlert] = []

    private let apiService: APIServiceProtocol
    private let settings: SettingsStore
    private let now: () -> Date

    private var campStartedAt: Date?

    public init(
        apiService: APIServiceProtocol,
        settings: SettingsStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.apiService = apiService
        self.settings = settings
        self.now = now
    }

    /// Feed in the latest VehicleState snapshot. Idempotent — same
    /// state passed in twice is a no-op.
    public func observe(_ state: VehicleState?) {
        guard let state else { return }
        if state.isCampModeOn {
            if campStartedAt == nil {
                campStartedAt = now()
                Log.vehicle.notice("camp mode detected on")
            }
        } else if campStartedAt != nil {
            Log.vehicle.notice("camp mode cleared")
            campStartedAt = nil
        }
        recompute()
    }

    /// Action handler for the camp-mode pill's "关闭" button. Hits
    /// the backend `set_climate_keeper_mode(0)` and clears the local
    /// timer optimistically on success. The next poll will confirm.
    public func clearCampMode(vehicleId: String) async -> Result<BaseResponse, APIError> {
        Log.vehicle.notice("clearCampMode → set_climate_keeper_mode(0)")
        let result = await apiService.setClimateKeeperMode(vehicleId: vehicleId, mode: 0)
        if case .success = result {
            campStartedAt = nil
            recompute()
        }
        return result
    }

    /// Exposed for tests so the duration math can be re-checked
    /// without waiting for a poll.
    public func recompute() {
        var next: [VehicleAlert] = []
        if let started = campStartedAt {
            let threshold = settings.campModeReminderMinutes
            if threshold > 0 {
                let minutes = max(0, Int(now().timeIntervalSince(started) / 60))
                let critical = minutes >= threshold
                next.append(VehicleAlert(
                    kind: .campMode,
                    title: "露营模式开启中",
                    detail: critical
                        ? "已开启 \(formatMinutes(minutes))，电池正在缓慢消耗"
                        : "已开启 \(formatMinutes(minutes))",
                    severity: critical ? .critical : .info,
                    primaryActionLabel: critical ? "关闭" : nil
                ))
            }
        }
        alerts = next
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分钟"
    }
}
