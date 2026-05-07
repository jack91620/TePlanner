import UIKit
import TePlannerKit

/// Glue between APNs registration callbacks (UIApplicationDelegate) and
/// our backend's /devices/register endpoint.
///
/// Flow:
/// 1. After UNUserNotificationCenter.requestAuthorization grants
///    permission, call `RemotePushRegistrar.shared.requestRegistration()`.
///    This calls UIApplication.registerForRemoteNotifications() on the
///    main thread.
/// 2. iOS asynchronously calls back into TePlannerAppDelegate's
///    didRegisterForRemoteNotificationsWithDeviceToken (or didFail).
///    The delegate forwards to `handleRegistration(token:)`.
/// 3. We POST the hex-encoded token to /devices/register so the
///    polling loop on the backend can deliver pushes when the app is
///    closed.
@MainActor
final class RemotePushRegistrar {
    static let shared = RemotePushRegistrar()

    private let apiService: APIServiceProtocol
    private var lastRegisteredToken: String?

    private init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
    }

    /// Tell iOS we want a device token. Idempotent; iOS dedupes its
    /// own pending registration call.
    func requestRegistration() {
        UIApplication.shared.registerForRemoteNotifications()
        Log.app.notice("requested APNs registration")
    }

    /// Apple delegate handed us a fresh device token. Hex-encode and
    /// POST to backend. Skips the call if the token hasn't changed
    /// since last successful upload — avoids hammering /devices/register
    /// on every cold launch.
    func handleRegistration(rawToken: Data) {
        let hexToken = rawToken.map { String(format: "%02x", $0) }.joined()
        Log.app.notice("APNs token received (len=\(hexToken.count, privacy: .public))")
        guard hexToken != lastRegisteredToken else {
            Log.app.debug("APNs token unchanged — skipping re-register")
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let result = await apiService.registerDeviceToken(hexToken, bundleId: Bundle.main.bundleIdentifier)
            switch result {
            case .success:
                Log.app.notice("device token registered with backend")
                self.lastRegisteredToken = hexToken
            case .failure(let error):
                Log.app.error("device token register failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func handleRegistrationFailure(_ error: Error) {
        Log.app.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }
}

/// SwiftUI's @main App can't directly receive UIApplicationDelegate
/// callbacks. We add a tiny adaptor that forwards just the two APNs
/// callbacks to RemotePushRegistrar; everything else stays default.
final class TePlannerAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            RemotePushRegistrar.shared.handleRegistration(rawToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            RemotePushRegistrar.shared.handleRegistrationFailure(error)
        }
    }
}
