import SwiftUI
import TePlannerKit
import AMapFoundationKit
import MAMapKit
import AMapSearchKit
import AMapLocationKit
import os

@main
struct TePlannerApp: App {
    @UIApplicationDelegateAdaptor(TePlannerAppDelegate.self) private var appDelegate

    init() {
        Self.bootstrapAMapSDK()
        Task { @MainActor in LocalNotificationScheduler.shared.bootstrap() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    private static func bootstrapAMapSDK() {
        let key = Bundle.main.object(forInfoDictionaryKey: "AMapAPIKey") as? String ?? ""
        if key.isEmpty {
            Log.app.fault("AMapAPIKey missing in Info.plist — check Config.xcconfig and rerun `make project`")
        } else {
            Log.app.notice("AMap key present (len=\(key.count, privacy: .public)), bundleId=\(Bundle.main.bundleIdentifier ?? "?", privacy: .public)")
        }
        AMapServices.shared().apiKey = key
        AMapServices.shared().enableHTTPS = true

        // Privacy compliance — required before instantiating any map / search /
        // location component. Mirrors Android's `MapsInitializer.updatePrivacy*`
        // and `ServiceSettings.updatePrivacy*` calls in TePlannerApp.kt.
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)

        AMapSearchAPI.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        AMapSearchAPI.updatePrivacyAgree(.didAgree)

        AMapLocationManager.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        AMapLocationManager.updatePrivacyAgree(.didAgree)

        Log.app.notice("AMap SDK initialized — privacy compliance accepted on MAMapView/AMapSearchAPI/AMapLocationManager")
    }
}
