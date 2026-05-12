import XCTest
@testable import TePlannerKit

@MainActor
final class CommandStatusStoreTests: XCTestCase {

    private var mock: MockAPIService!
    private var store: CommandStatusStore!

    override func setUp() async throws {
        mock = MockAPIService()
        // Empty defaults — individual tests override.
        mock.mockPendingCommands = .success(PendingCommandListResponse(pending: []))
        mock.mockQueuedCommands = .success(QueuedCommandListResponse(queued: []))
        store = CommandStatusStore(apiService: mock)
    }

    private func makePending(
        id: Int = 1,
        status: String = "pending",
        dispatchedAt: Date = Date(),
        confirmedAt: Date? = nil,
    ) -> PendingCommand {
        PendingCommand(
            id: id,
            capability: "tesla.climate.set_keeper_mode",
            expectedState: ["vehicle.climate.keeper_mode": .int(0)],
            dispatchedAt: dispatchedAt,
            confirmedAt: confirmedAt,
            status: status,
        )
    }

    private func makeQueued(
        id: Int = 1,
        status: String = "queued",
        sentAt: Date? = nil,
        droppedAt: Date? = nil,
    ) -> QueuedCommand {
        QueuedCommand(
            id: id,
            capability: "tesla.security.set_sentry",
            params: ["on": .bool(true)],
            dispatchPolicy: "queue_if_offline",
            queuedAt: Date().addingTimeInterval(-10),
            sentAt: sentAt,
            droppedAt: droppedAt,
            ttlSeconds: 300,
            error: nil,
            status: status,
        )
    }

    // MARK: - refresh

    func test_refresh_empty_clearsActiveState() async {
        // Pre-seed: pretend we had a pending banner.
        mock.mockPendingCommands = .success(PendingCommandListResponse(
            pending: [makePending(status: "pending")]))
        await store.refresh()
        XCTAssertNotNil(store.activePending)

        // Now backend returns empty (e.g. row aged out past 5min cutoff).
        mock.mockPendingCommands = .success(PendingCommandListResponse(pending: []))
        await store.refresh()
        XCTAssertNil(store.activePending, "empty response must clear stuck banner")
    }

    func test_refresh_populatesPending() async {
        let p = makePending(status: "pending")
        mock.mockPendingCommands = .success(PendingCommandListResponse(pending: [p]))
        await store.refresh()
        XCTAssertEqual(store.activePending?.id, p.id)
        XCTAssertEqual(store.activePending?.status, "pending")
    }

    func test_refresh_populatesQueued() async {
        let q = makeQueued(status: "queued")
        mock.mockQueuedCommands = .success(QueuedCommandListResponse(queued: [q]))
        await store.refresh()
        XCTAssertEqual(store.activeQueued?.id, q.id)
    }

    func test_refresh_failureDoesNotClearActiveState() async {
        // Seed with success.
        mock.mockPendingCommands = .success(PendingCommandListResponse(
            pending: [makePending(status: "pending")]))
        await store.refresh()
        XCTAssertNotNil(store.activePending)

        // Network failure — keep showing prev state (don't flicker
        // banner because of transient connectivity).
        mock.mockPendingCommands = .failure(.serverError(statusCode: 500, message: "down"))
        await store.refresh()
        XCTAssertNotNil(
            store.activePending,
            "network failure should not erase known-good pending status",
        )
    }

    // MARK: - resolved-flash behaviour

    func test_confirmedStatus_showsFor3sThenClears() async {
        let confirmed = makePending(status: "confirmed", confirmedAt: Date())
        mock.mockPendingCommands = .success(PendingCommandListResponse(pending: [confirmed]))

        // First poll: see confirmed → banner stays (flash window starts).
        await store.refresh()
        XCTAssertNotNil(store.activePending)

        // Immediate re-poll within 3s — banner persists.
        await store.refresh()
        XCTAssertNotNil(store.activePending)

        // After 3.1s of real time, next refresh should clear.
        try? await Task.sleep(nanoseconds: 3_100_000_000)
        await store.refresh()
        XCTAssertNil(store.activePending, "confirmed banner must clear after 3s flash")
    }

    func test_pendingThenConfirmed_resetsFlashClock() async {
        // First observation is still pending.
        let pending = makePending(status: "pending")
        mock.mockPendingCommands = .success(PendingCommandListResponse(pending: [pending]))
        await store.refresh()

        // Then transitions to confirmed (same row id).
        let confirmed = makePending(status: "confirmed", confirmedAt: Date())
        mock.mockPendingCommands = .success(PendingCommandListResponse(pending: [confirmed]))
        await store.refresh()
        XCTAssertEqual(store.activePending?.status, "confirmed")

        // The 3-second clock starts AT the transition, not at dispatch time.
        // Immediately re-polling stays under 3s → banner persists.
        await store.refresh()
        XCTAssertNotNil(store.activePending)
    }

    // MARK: - queued resolution afterglow

    func test_queued_sentAndOlderThan5s_disappears() async {
        let staleSent = makeQueued(
            status: "sent",
            sentAt: Date().addingTimeInterval(-10),
        )
        mock.mockQueuedCommands = .success(QueuedCommandListResponse(queued: [staleSent]))
        await store.refresh()
        XCTAssertNil(store.activeQueued)
    }

    func test_queued_recentlySent_stillShown() async {
        let recent = makeQueued(
            status: "sent",
            sentAt: Date().addingTimeInterval(-1),
        )
        mock.mockQueuedCommands = .success(QueuedCommandListResponse(queued: [recent]))
        await store.refresh()
        XCTAssertNotNil(store.activeQueued)
    }

    // MARK: - cancelQueued

    func test_cancelQueued_callsAPIAndRefreshes() async {
        let q = makeQueued(status: "queued")
        mock.mockQueuedCommands = .success(QueuedCommandListResponse(queued: [q]))
        await store.refresh()
        XCTAssertNotNil(store.activeQueued)

        // After cancel, backend returns empty.
        mock.mockQueuedCommands = .success(QueuedCommandListResponse(queued: []))
        await store.cancelQueued(id: q.id)

        XCTAssertEqual(mock.lastCancelQueuedId, q.id)
        XCTAssertNil(store.activeQueued, "cancel should immediately refresh state")
    }

    // MARK: - pollUntilSettled

    func test_pollUntilSettled_breaksWhenActivePendingClears() async {
        // Start with pending row.
        let pending = makePending(status: "pending")
        mock.mockPendingCommands = .success(PendingCommandListResponse(pending: [pending]))

        // After ~1.5s, simulate backend confirming + the row sliding
        // out of the 5min window so the next poll sees empty.
        let task = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                self.mock.mockPendingCommands = .success(
                    PendingCommandListResponse(pending: []))
            }
        }

        let start = Date()
        await store.pollUntilSettled()
        let elapsed = Date().timeIntervalSince(start)
        _ = await task.value

        XCTAssertLessThan(
            elapsed, 12,
            "must break before 12s deadline once activePending nils out",
        )
        XCTAssertNil(store.activePending)
    }

    func test_pollUntilSettled_respectsDeadline() async {
        // Pending row that never resolves.
        mock.mockPendingCommands = .success(PendingCommandListResponse(
            pending: [makePending(status: "pending")]))

        let start = Date()
        await store.pollUntilSettled()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThanOrEqual(elapsed, 60, "should run the full 60s deadline")
        XCTAssertLessThan(elapsed, 62, "shouldn't overshoot deadline meaningfully")
    }
}
