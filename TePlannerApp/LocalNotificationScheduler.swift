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

    private var lastSeenCriticalKinds: Set<VehicleAlert.Kind> = []
    private var permissionRequested = false

    func bootstrap() {
        UNUserNotificationCenter.current().delegate = self
        requestPermissionIfNeeded()
    }

    func requestPermissionIfNeeded() {
        guard !permissionRequested else { return }
        permissionRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Log.app.error("local-notif permission error: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.app.notice("local-notif permission \(granted ? "granted" : "denied", privacy: .public)")
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

    private func schedule(_ alert: VehicleAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.detail
        content.sound = .default
        content.categoryIdentifier = alert.kind.rawValue

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

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // App is in foreground — pill is already showing the same alert,
        // banner would be redundant noise. Suppress.
        completionHandler([])
    }
}
