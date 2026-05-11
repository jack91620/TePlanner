import XCTest
@testable import TePlannerKit

/// Pin the reconcile + sweep policies. App-target glue
/// (LocalNotificationScheduler) just maps UNNotification → DeliveredItem
/// and calls these.
final class NotificationReconcilePolicyTests: XCTestCase {

    private typealias Item = NotificationReconcilePolicy.DeliveredItem

    private let now = Date()

    private func item(
        _ id: String, category: String = "campMode", at: Date? = nil,
    ) -> Item {
        Item(identifier: id, categoryIdentifier: category, date: at ?? now)
    }

    // MARK: - reconcile

    func test_reconcile_removesKindNoLongerFiring() {
        let delivered = [
            item("1", category: "campMode"),
            item("2", category: "sentryMode"),
        ]
        // Only campMode is currently firing; sentry one should be removed.
        let toRemove = NotificationReconcilePolicy.reconcile(
            delivered: delivered, firingKinds: ["campMode"],
        )
        XCTAssertEqual(toRemove, ["2"])
    }

    func test_reconcile_keepsKindStillFiring() {
        let delivered = [item("1", category: "campMode")]
        let toRemove = NotificationReconcilePolicy.reconcile(
            delivered: delivered, firingKinds: ["campMode"],
        )
        XCTAssertTrue(toRemove.isEmpty)
    }

    func test_reconcile_removesAllWhenFiringSetEmpty() {
        let delivered = [
            item("1", category: "campMode"),
            item("2", category: "sentryMode"),
            item("3", category: "leftUnlocked"),
        ]
        let toRemove = NotificationReconcilePolicy.reconcile(
            delivered: delivered, firingKinds: [],
        )
        XCTAssertEqual(Set(toRemove), Set(["1", "2", "3"]))
    }

    func test_reconcile_skipsPreheatReminder() {
        // Preheat has its own schedule lifecycle — not driven by
        // is_firing, so reconcile must leave it alone.
        let delivered = [
            item("preheat-1", category: NotificationReconcilePolicy.preheatId),
            item("alert-1", category: "campMode"),
        ]
        let toRemove = NotificationReconcilePolicy.reconcile(
            delivered: delivered, firingKinds: [],
        )
        XCTAssertEqual(toRemove, ["alert-1"], "preheat banner must survive an empty firing set")
    }

    func test_reconcile_skipsSamplePreviewNotifs() {
        // "试发通知预览" samples have category like "sample.preview-…"
        // and shouldn't be reconciled away (they auto-dismiss via
        // their own preview lifecycle).
        let delivered = [
            item("s1", category: "sample.previewx"),
            item("alert-1", category: "campMode"),
        ]
        let toRemove = NotificationReconcilePolicy.reconcile(
            delivered: delivered, firingKinds: ["campMode"],
        )
        XCTAssertTrue(toRemove.isEmpty)
    }

    func test_reconcile_skipsEmptyCategoryIdentifier() {
        // Uncategorised banners (legacy / system) shouldn't be touched.
        let delivered = [item("uncat", category: "")]
        let toRemove = NotificationReconcilePolicy.reconcile(
            delivered: delivered, firingKinds: [],
        )
        XCTAssertTrue(toRemove.isEmpty)
    }

    // MARK: - sweepStale

    func test_sweepStale_dropsOnlyExpired() {
        let twoHoursAgo = now.addingTimeInterval(-2 * 3600)
        let fifteenHoursAgo = now.addingTimeInterval(-15 * 3600)

        let delivered = [
            item("recent", category: "campMode", at: twoHoursAgo),
            item("old", category: "campMode", at: fifteenHoursAgo),
        ]
        let stale = NotificationReconcilePolicy.sweepStale(
            delivered: delivered, now: now, maxAgeSeconds: 12 * 3600,
        )
        XCTAssertEqual(stale, ["old"])
    }

    func test_sweepStale_honoursCustomCutoff() {
        let oneHourAgo = now.addingTimeInterval(-3600)
        let delivered = [item("h1", category: "campMode", at: oneHourAgo)]

        // 30-min cutoff: 1h-old item is stale.
        let strict = NotificationReconcilePolicy.sweepStale(
            delivered: delivered, now: now, maxAgeSeconds: 30 * 60,
        )
        XCTAssertEqual(strict, ["h1"])

        // 2h cutoff: same item survives.
        let lenient = NotificationReconcilePolicy.sweepStale(
            delivered: delivered, now: now, maxAgeSeconds: 2 * 3600,
        )
        XCTAssertTrue(lenient.isEmpty)
    }

    func test_sweepStale_doesNotSpareCategoryFilters() {
        // sweep is age-only — preheat / sample banners still get
        // collected if they're past the cutoff (they should never
        // be that old anyway, but the contract is pure-age).
        let veryOld = now.addingTimeInterval(-25 * 3600)
        let delivered = [
            item("preheat-1", category: NotificationReconcilePolicy.preheatId, at: veryOld),
        ]
        let stale = NotificationReconcilePolicy.sweepStale(
            delivered: delivered, now: now,
        )
        XCTAssertEqual(stale, ["preheat-1"])
    }

    func test_sweepStale_emptyInputReturnsEmpty() {
        XCTAssertTrue(NotificationReconcilePolicy.sweepStale(
            delivered: [], now: now).isEmpty
        )
    }
}
