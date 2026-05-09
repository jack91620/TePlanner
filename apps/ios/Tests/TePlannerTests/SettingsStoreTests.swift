import XCTest
@testable import TePlannerKit

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: UserDefaultsSettingsStore!
    private let suiteName = "TePlannerTests.SettingsStore"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        store = UserDefaultsSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultsMatchAndroidBaseline() {
        XCTAssertEqual(store.teslaLinked, false)
        XCTAssertEqual(store.targetArrivalSoc, 20)
        XCTAssertEqual(store.minChargingSoc, 10)
        XCTAssertEqual(store.preferSupercharger, true)
        XCTAssertEqual(store.distanceUnit, .kilometers)
    }

    func testRoundtripValues() {
        store.teslaLinked = true
        store.targetArrivalSoc = 35
        store.minChargingSoc = 5
        store.preferSupercharger = false
        store.distanceUnit = .miles

        let reread = UserDefaultsSettingsStore(defaults: defaults)
        XCTAssertEqual(reread.teslaLinked, true)
        XCTAssertEqual(reread.targetArrivalSoc, 35)
        XCTAssertEqual(reread.minChargingSoc, 5)
        XCTAssertEqual(reread.preferSupercharger, false)
        XCTAssertEqual(reread.distanceUnit, .miles)
    }

    func testResetRestoresDefaults() {
        store.teslaLinked = true
        store.targetArrivalSoc = 99
        store.distanceUnit = .miles
        store.reset()
        XCTAssertEqual(store.teslaLinked, false)
        XCTAssertEqual(store.targetArrivalSoc, 20)
        XCTAssertEqual(store.distanceUnit, .kilometers)
    }
}
