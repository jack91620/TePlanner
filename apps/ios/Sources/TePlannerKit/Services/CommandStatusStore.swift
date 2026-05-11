import Foundation

/// Shared store for the in-flight VCP command status that drives
/// the Hub's CommandStatusBanner.
///
/// **Why this is a separate object:** the banner lives in HubView,
/// but commands are dispatched from many places (chip taps,
/// HubChargeLimitCard, BatteryView's manual apply, AlertPill primary
/// action, RoutePreviewVM's send-to-car). Each dispatcher needs to
/// kick off the converge poll so the banner flips
/// "正在关闭…" → "已关闭" → cleared within ~12 s of the actual VCP
/// command. Without a shared instance, each call site would need its
/// own copy of the polling logic and the bug from f37a26f
/// (banner-stuck-on-pending) would re-emerge whenever a new dispatch
/// site is added.
///
/// Owned at app boot, injected wherever needed (HubView observes,
/// other views just call `pollUntilSettled()` after dispatch).
@MainActor
public final class CommandStatusStore: ObservableObject {

    // MARK: - Public state (HubView observes for banner rendering)

    /// Most recently observed pending command. nil = no banner.
    @Published public private(set) var activePending: PendingCommand?

    /// Most recently observed queued command (Phase 10 sleep-aware
    /// command queue). nil = no banner.
    @Published public private(set) var activeQueued: QueuedCommand?

    // MARK: - Internals

    private let apiService: APIServiceProtocol
    /// First time we saw the active pending row reach a terminal
    /// status. Used to dismiss the banner after the post-resolution
    /// "已关闭" flash window expires.
    private var pendingResolvedAt: Date?

    public init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }

    // MARK: - Public API

    /// One-shot fetch from /vehicles/commands/pending +
    /// /vehicles/commands/queued. Updates @Published state.
    public func refresh() async {
        async let pendingResp = apiService.fetchPendingCommands()
        async let queuedResp = apiService.fetchQueuedCommands()
        let (p, q) = await (pendingResp, queuedResp)
        applyPending(p)
        applyQueued(q)
    }

    /// After dispatching a VCP command, poll on a 1 s cadence until
    /// the banner flips back to nil (terminal status observed +
    /// 3 s post-resolution flash elapsed) OR a 12 s deadline hits.
    /// Caller fires-and-forgets in a Task; UI updates via
    /// @Published bindings.
    public func pollUntilSettled() async {
        let deadline = Date().addingTimeInterval(12)
        await refresh()
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await refresh()
            // Exit only AFTER activePending is nil — see f37a26f for
            // why "break on first confirmed" was the wrong condition.
            if activePending == nil { break }
        }
    }

    /// Cancel a queued command and refresh. Exposed for the queued-row
    /// banner's "取消" button.
    public func cancelQueued(id: Int) async {
        _ = await apiService.cancelQueuedCommand(id: id)
        await refresh()
    }

    // MARK: - Internal helpers

    private func applyPending(_ result: Result<PendingCommandListResponse, APIError>) {
        // Transient network failures must not erase a known-good
        // banner — that would cause "正在关闭…" to flicker off + on
        // every time the poll loop hits a 502. Only act on
        // authoritative success responses.
        guard case .success(let resp) = result else { return }

        guard let latest = resp.pending.first else {
            // Authoritative empty — backend has nothing; clear.
            activePending = nil
            pendingResolvedAt = nil
            return
        }
        let isResolved = latest.status != "pending"
        if isResolved && pendingResolvedAt == nil {
            pendingResolvedAt = Date()
        }
        if isResolved, let ts = pendingResolvedAt,
           Date().timeIntervalSince(ts) > 3 {
            activePending = nil
            pendingResolvedAt = nil
        } else {
            activePending = latest
            if !isResolved { pendingResolvedAt = nil }
        }
    }

    private func applyQueued(_ result: Result<QueuedCommandListResponse, APIError>) {
        // Same network-blip rule as pending. Only authoritative
        // success can clear / set the banner.
        guard case .success(let resp) = result else { return }
        let row = resp.queued.first { row in
            if row.status == "queued" { return true }
            // Brief afterglow so user sees the resolved → vanish flow.
            let resolvedAt = row.sentAt ?? row.droppedAt
            if let resolvedAt {
                return Date().timeIntervalSince(resolvedAt) < 5
            }
            return false
        }
        activeQueued = row
    }
}
