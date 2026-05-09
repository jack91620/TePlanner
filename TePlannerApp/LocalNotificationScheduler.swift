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
final class LocalNotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationScheduler()

    /// Identifier reserved for the Phase 5.5 "时间到了，出发前预热"
    /// notification. Distinct namespace from VehicleAlert.Kind.rawValue
    /// so they can't collide.
    static let preheatNotificationId = "scheduled_preheat"

    private var lastSeenCriticalKinds: Set<VehicleAlert.Kind> = []
    private var permissionRequested = false
    /// Set externally (HubView.task) so the delegate can hand the
    /// preheat tap off to the right place. nil means "no listener" —
    /// notification is silently dropped.
    var onPreheatTapped: (() -> Void)?
    /// Fired when the user taps a notification's primary action
    /// button (e.g. "关闭露营") from the lock screen / notification
    /// center. Receives the alert kind raw value so HubView can
    /// route to AutomationEngine.performPrimaryAction(...).
    /// Setting this clears any buffered tap that arrived before
    /// the callback was wired (cold-launch case).
    var onAlertPrimaryAction: ((String) -> Void)? {
        didSet {
            if let buffered = bufferedAlertCategoryId, let handler = onAlertPrimaryAction {
                bufferedAlertCategoryId = nil
                handler(buffered)
            }
        }
    }
    /// Set on cold launch when the user tapped a notification action
    /// before HubView had wired `onAlertPrimaryAction`. Replayed when
    /// the callback eventually shows up.
    private var bufferedAlertCategoryId: String?

    func bootstrap() {
        UNUserNotificationCenter.current().delegate = self
        registerActionCategories()
        requestPermissionIfNeeded()
    }

    /// Wire up UNNotificationCategory actions so users can act
    /// directly from the notification center / lock screen instead
    /// of opening the app. Mirrors iOS Shortcuts inline-action UX.
    /// Each category is keyed by VehicleAlert.Kind so the
    /// scheduler's per-alert `categoryIdentifier = kind.rawValue`
    /// lights up the right buttons.
    private func registerActionCategories() {
        let dismissAction = UNNotificationAction(
            identifier: "dismiss",
            title: "我知道了",
            options: []
        )
        let closeCampAction = UNNotificationAction(
            identifier: "primary",
            title: "关闭露营",
            options: [.authenticationRequired]
        )
        let closeSentryAction = UNNotificationAction(
            identifier: "primary",
            title: "关闭哨兵",
            options: [.authenticationRequired]
        )
        let categories: [UNNotificationCategory] = [
            UNNotificationCategory(
                identifier: VehicleAlert.Kind.campMode.rawValue,
                actions: [closeCampAction, dismissAction],
                intentIdentifiers: [], options: [],
            ),
            UNNotificationCategory(
                identifier: VehicleAlert.Kind.sentryMode.rawValue,
                actions: [closeSentryAction, dismissAction],
                intentIdentifiers: [], options: [],
            ),
            UNNotificationCategory(
                identifier: VehicleAlert.Kind.chargeComplete.rawValue,
                actions: [dismissAction],
                intentIdentifiers: [], options: [],
            ),
            UNNotificationCategory(
                identifier: VehicleAlert.Kind.cabinOverheat.rawValue,
                actions: [dismissAction],
                intentIdentifiers: [], options: [],
            ),
            UNNotificationCategory(
                identifier: VehicleAlert.Kind.leftUnlocked.rawValue,
                actions: [
                    UNNotificationAction(
                        identifier: "primary",
                        title: "锁车",
                        options: [.authenticationRequired]
                    ),
                    dismissAction,
                ],
                intentIdentifiers: [], options: [],
            ),
            UNNotificationCategory(
                identifier: VehicleAlert.Kind.closureLeftOpen.rawValue,
                actions: [dismissAction],
                intentIdentifiers: [], options: [],
            ),
            UNNotificationCategory(
                identifier: VehicleAlert.Kind.lowBattery.rawValue,
                actions: [dismissAction],
                intentIdentifiers: [], options: [],
            ),
            UNNotificationCategory(
                identifier: VehicleAlert.Kind.weekdayPreheat.rawValue,
                actions: [
                    UNNotificationAction(
                        identifier: "primary",
                        title: "立即预热",
                        options: [.authenticationRequired]
                    ),
                    dismissAction,
                ],
                intentIdentifiers: [], options: [],
            ),
            // Geofence categories — capability is rule-defined (could
            // be set_sentry on enter, door_lock on exit, etc.) so the
            // category title is generic '执行操作'. The actual title
            // shown on the lock screen is rule-spec's
            // primary_action_label IF the notification is delivered as
            // a remote APNs push (server can override per-message); for
            // local-fired previews the user sees this generic label.
            UNNotificationCategory(
                identifier: VehicleAlert.Kind.geofenceEnter.rawValue,
                actions: [
                    UNNotificationAction(
                        identifier: "primary",
                        title: "执行操作",
                        options: [.authenticationRequired]
                    ),
                    dismissAction,
                ],
                intentIdentifiers: [], options: [],
            ),
            UNNotificationCategory(
                identifier: VehicleAlert.Kind.geofenceExit.rawValue,
                actions: [
                    UNNotificationAction(
                        identifier: "primary",
                        title: "执行操作",
                        options: [.authenticationRequired]
                    ),
                    dismissAction,
                ],
                intentIdentifiers: [], options: [],
            ),
        ]
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
            if granted {
                Task { @MainActor in
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
        if actionId == "primary" && !categoryId.isEmpty {
            // User tapped the inline action button on a rule's
            // notification (e.g. "关闭露营" / "关闭哨兵"). Forward to
            // HubView so AutomationEngine can dispatch the rule's
            // configured primary capability. Cold-launch case: if
            // HubView hasn't wired its callback yet, buffer for
            // replay (didSet on onAlertPrimaryAction handles drain).
            Task { @MainActor in
                let scheduler = LocalNotificationScheduler.shared
                if let handler = scheduler.onAlertPrimaryAction {
                    handler(categoryId)
                } else {
                    scheduler.bufferedAlertCategoryId = categoryId
                }
                completionHandler()
            }
            return
        }
        // Default tap (notification body) and "我知道了" both just
        // open the app / dismiss; nothing else to do here.
        completionHandler()
    }
}
