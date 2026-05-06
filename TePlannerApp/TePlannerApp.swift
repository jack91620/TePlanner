import SwiftUI
import TePlannerKit
import AMapFoundationKit
import MAMapKit
import AMapSearchKit
import AMapLocationKit

@main
struct TePlannerApp: App {
    init() {
        Self.bootstrapAMapSDK()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    private static func bootstrapAMapSDK() {
        let key = Bundle.main.object(forInfoDictionaryKey: "AMapAPIKey") as? String ?? ""
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
    }
}
