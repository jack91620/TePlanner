import Foundation
import UserNotifications
import TePlannerKit

/// Schedules / cancels iOS local notifications based on the
/// AutomationEngine's `alerts` stream. The pill on HomeView covers
/// the foreground case; this layer covers "user closed the app right
/// before camp mode tripped its 2-hour threshold" — local
/// notifications fire even when the app process isn't active, as long
/// as iOS hasn't suspended the system completely.
///
/// Limits / known gaps:
/// - Notifications are only scheduled when the engine *evaluates* the
///   trigger, which requires the app to have been opened recently.
///   The "user hasn't opened the app in 8 hours" case is the
///   unreachable one until APNs + server-side polling lands.
/// - Foreground display is suppressed by `userNotificationCenter
///   (_:willPresent:)` because the pill is already showing the same
///   info; banner + pill is redundant.
@MainActor
final class LocalNotificationScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationScheduler()

    /// Identifier reserved for the Phase 5.5 "时间到了，出发前预热"
    /// notification. Distinct namespace from VehicleAlert.Kind.rawValue
    /// so they can't collide.
    static let preheatNotificationId = "scheduled_preheat"

    private var lastSeenCriticalKinds: Set<VehicleAlert.Kind> = []
    private var permissionRequested = false

    /// Published authorization status — UI subscribes to drive a
    /// "通知未开启" re-prompt banner when it's `.denied`. Refreshed
    /// from `getNotificationSettings` on scene-active so changes the
    /// user makes in iOS Settings reflect immediately.
    @Published private(set) var authStatus: UNAuthorizationStatus = .notDetermined

    /// Refresh `authStatus` from the system. Cheap; safe to call on
    /// every foreground tick.
    func refreshAuthStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.authStatus = settings.authorizationStatus
            }
        }
    }
    /// Set externally (HubView.task) so the delegate can hand the
    /// preheat tap off to the right place. nil means "no listener" —
    /// notification is silently dropped.
    var onPreheatTapped: (() -> Void)?
    /// 2026-05-11 — `onAlertPrimaryAction` and the cold-launch
    /// buffering for it have been removed. Car-control actions now
    /// live on Hub status chips (tap-to-confirm), not on notification
    /// inline buttons. HubView no longer wires this callback.

    func bootstrap() {
        UNUserNotificationCenter.current().delegate = self
        registerActionCategories()
        requestPermissionIfNeeded()
    }

    /// 2026-05-11 — car-control actions ("关闭露营" / "关闭哨兵" /
    /// "锁车" / "立即预热") have been REMOVED from notification
    /// categories. The new UX: notification is informational only;
    /// tapping it opens the app, where the Hub statusCard chips
    /// surface the same controls behind a tap-to-confirm dialog.
    ///
    /// Why: control buttons on the lock screen sent commands without
    /// the user seeing the live state first — and from a 1.5cm wide
    /// button with no recovery path. With chips on Hub the user sees
    /// the current state (露营 ON / 哨兵 ON / 未锁) first, taps the
    /// chip, sees a confirmation dialog, then the command goes out.
    /// Same controls work whether or not a notification ever fired.
    ///
    /// We still register categories so iOS keeps the notification
    /// grouped under a thread, but each only carries a dismiss action.
    private func registerActionCategories() {
        let dismissAction = UNNotificationAction(
            identifier: "dismiss",
            title: "我知道了",
            options: []
        )
        let allKinds: [VehicleAlert.Kind] = [
            .campMode, .sentryMode, .chargeComplete, .cabinOverheat,
            .leftUnlocked, .closureLeftOpen, .lowBattery, .weekdayPreheat,
            .geofenceEnter, .geofenceExit,
        ]
        let categories = allKinds.map { kind in
            UNNotificationCategory(
                identifier: kind.rawValue,
                actions: [dismissAction],
                intentIdentifiers: [], options: [],
            )
        }
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
    }

    func requestPermissionIfNeeded() {
        guard !permissionRequested else { return }
        permissionRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                Log.app.error("local-notif permission error: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.app.notice("local-notif permission \(granted ? "granted" : "denied", privacy: .public)")
            }
            Task { @MainActor in
                self.refreshAuthStatus()
                if granted {
                    RemotePushRegistrar.shared.requestRegistration()
                }
            }
        }
    }

    /// Diff incoming alerts against our last-seen set:
    /// - kinds that were not critical and now are → schedule a notification
    /// - kinds that were critical and now aren't → cancel pending+delivered
    func applyAlerts(_ alerts: [VehicleAlert]) {
        let criticalNow = Set(alerts.filter { $0.severity == .critical }.map(\.kind))

        let newlyCritical = criticalNow.subtracting(lastSeenCriticalKinds)
        let resolved = lastSeenCriticalKinds.subtracting(criticalNow)

        for kind in newlyCritical {
            if let alert = alerts.first(where: { $0.kind == kind }) {
                schedule(alert)
            }
        }
        for kind in resolved {
            cancel(kind: kind)
        }

        lastSeenCriticalKinds = criticalNow
    }

    /// Public test fire — surfaces a sample notification to let the
    /// user preview what a rule's notification will look like in the
    /// system notification center. Used by the rule detail page's
    /// "试发通知" button so the user can verify wording / severity
    /// before relying on the rule.
    func fireSample(title: String, body: String, identifier: String = "preview") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "com.teplanner.ios.preview"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "sample.\(identifier).\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.app.error("sample-notif failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func schedule(_ alert: VehicleAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.detail
        content.sound = .default
        content.categoryIdentifier = alert.kind.rawValue
        // iOS groups notifications with the same threadIdentifier into
        // one stack on the lock screen. Use a single namespace so a
        // burst of rule fires (e.g. car came online → 3 alerts in 5s)
        // doesn't bury the user's notification center.
        content.threadIdentifier = "com.teplanner.ios.automation"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: alert.kind.rawValue,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.app.error("local-notif schedule failed for \(alert.kind.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                Log.app.notice("local-notif scheduled for \(alert.kind.rawValue, privacy: .public)")
            }
        }
    }

    private func cancel(kind: VehicleAlert.Kind) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [kind.rawValue])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [kind.rawValue])
        Log.app.notice("local-notif cancelled for \(kind.rawValue, privacy: .public)")
    }

    /// Walk the system's delivered notifications and remove any whose
    /// kind is no longer in the supplied "firing" set. Idempotent.
    ///
    /// 2026-05-11: needed because the engine.alerts pipe became dead
    /// after D.6 (no `applyServerAlerts` wiring in production), so
    /// the diff in `applyAlerts(_:)` never trips a cancel for old
    /// banners. This reconciler is driven by `record.isFiring` from
    /// the server's RuleResponse — single source of truth across
    /// platforms — and strips any leftover notification whose rule
    /// is no longer firing, including stale APNs banners from a
    /// previous app session.
    ///
    /// Call from HubView on each rules refresh.
    func reconcileDelivered(firingKinds: Set<String>) {
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            let categoriesToDrop: [String] = delivered.compactMap { notif in
                let category = notif.request.content.categoryIdentifier
                guard !category.isEmpty,
                      category != Self.preheatNotificationId,
                      !category.hasPrefix("sample.") else { return nil }
                return firingKinds.contains(category) ? nil : notif.request.identifier
            }
            guard !categoriesToDrop.isEmpty else { return }
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: categoriesToDrop
            )
            Log.app.notice("reconciled \(categoriesToDrop.count, privacy: .public) stale local-notif(s) — kinds no longer firing")
        }
    }

    // MARK: - Phase 5.5 scheduled-departure preheat

    /// (Re)schedule the preheat reminder for the given departure.
    /// Always cancels the previous schedule first so changing the
    /// time / lead doesn't double-fire.
    func schedulePreheat(for departure: ScheduledDeparture) {
        cancelPreheat()
        let fireAt = departure.fireAt
        let interval = fireAt.timeIntervalSinceNow
        guard interval > 0 else {
            Log.app.notice("preheat schedule skipped: fireAt already passed")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = departure.label.map { "出发提醒 · \($0)" } ?? "出发提醒"
        content.body = "再 \(departure.leadTimeMinutes) 分钟出发，点此预热车舱。"
        content.sound = .default
        content.categoryIdentifier = Self.preheatNotificationId

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.preheatNotificationId,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.app.error("preheat schedule failed: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.app.notice("preheat scheduled in \(Int(interval), privacy: .public)s")
            }
        }
    }

    func cancelPreheat() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.preheatNotificationId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.preheatNotificationId])
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Preheat reminders are time-critical — show the banner even
        // in foreground so the user can act on it immediately. '试发
        // 通知预览' samples need foreground display too, otherwise the
        // user just sits in the rule detail page wondering whether
        // the test fired (since the alert pill only shows real alerts).
        // Other (alert pill) notifications stay suppressed since the
        // pill already covers the foreground case.
        let id = notification.request.identifier
        if id == Self.preheatNotificationId || id.hasPrefix("sample.") {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        let actionId = response.actionIdentifier
        let categoryId = request.content.categoryIdentifier
        if request.identifier == Self.preheatNotificationId {
            Task { @MainActor in
                LocalNotificationScheduler.shared.onPreheatTapped?()
                completionHandler()
            }
            return
        }
        // 2026-05-11 — primary actions removed from notification
        // categories. All tap-paths fall through to "open the app";
        // user takes any car-control action via the Hub status chips
        // where they can confirm against the live state. The
        // categoryId / actionId fields are kept in case future iOS
        // versions add system-level handling we want to log.
        _ = (actionId, categoryId)
        completionHandler()
    }
}
