import Foundation

/// Pure-function policy for deciding which delivered local
/// notifications to dismiss. `LocalNotificationScheduler` (in the
/// app target) glues this to `UNUserNotificationCenter`; the logic
/// lives here so it can be unit-tested without UN APIs.
///
/// Two policies:
/// 1. `reconcile`: drop banners whose kind is no longer firing.
///    Source of truth = server's `is_firing` set from /automations.
/// 2. `sweepStale`: hard age cap (default 12h) for the cold-start
///    case — anything older than that is almost certainly leftover
///    from a previous session and should not greet the user with
///    yesterday's news.
public enum NotificationReconcilePolicy {

    /// Lightweight stand-in for `UNNotification` so tests don't need
    /// to construct real ones. Mirrors the fields the policy actually
    /// reads.
    public struct DeliveredItem: Equatable {
        public let identifier: String
        public let categoryIdentifier: String
        public let date: Date

        public init(identifier: String, categoryIdentifier: String, date: Date) {
            self.identifier = identifier
            self.categoryIdentifier = categoryIdentifier
            self.date = date
        }
    }

    /// IDs that are exempt from reconcile — preheat reminder + the
    /// rule-builder "试发" samples. They have their own lifecycles.
    public static let preheatId = "scheduled-departure-preheat"
    public static let samplePrefix = "sample."

    /// Given the system's currently-delivered notifications and the
    /// server-reported firing-kind set, return the identifiers that
    /// should be removed.
    ///
    /// Filters out:
    /// - empty categoryIdentifier (notif wasn't categorised — leave alone)
    /// - preheat reminder
    /// - sample.* (rule-builder previews)
    /// - kinds still in the firing set
    public static func reconcile(
        delivered: [DeliveredItem],
        firingKinds: Set<String>,
    ) -> [String] {
        delivered.compactMap { item in
            let category = item.categoryIdentifier
            guard !category.isEmpty,
                  category != preheatId,
                  !category.hasPrefix(samplePrefix) else {
                return nil
            }
            return firingKinds.contains(category) ? nil : item.identifier
        }
    }

    /// 12-hour default — see LocalNotificationScheduler.staleAgeSweep
    /// for why. Server REPUSH_GUARD caps at ~4h, so 12h is well past
    /// the "real notif from earlier today" threshold but well within
    /// "yesterday's banner" range.
    public static let defaultStaleAgeSeconds: TimeInterval = 12 * 60 * 60

    /// Given a list of delivered notifications and a reference time
    /// (usually "now"), return identifiers older than `maxAgeSeconds`.
    public static func sweepStale(
        delivered: [DeliveredItem],
        now: Date,
        maxAgeSeconds: TimeInterval = defaultStaleAgeSeconds,
    ) -> [String] {
        let cutoff = now.addingTimeInterval(-maxAgeSeconds)
        return delivered
            .filter { $0.date < cutoff }
            .map { $0.identifier }
    }
}
