import XCTest
@testable import TePlannerKit

@MainActor
final class AuthSessionTests: XCTestCase {
    private var storage: InMemorySecureStorage!
    private var settings: InMemorySettingsStore!
    private var session: AuthSession!

    override func setUp() async throws {
        storage = InMemorySecureStorage()
        settings = InMemorySettingsStore()
        session = AuthSession(secureStorage: storage, settings: settings)
    }

    func testFreshSessionIsLoggedOut() {
        XCTAssertFalse(session.isLoggedIn)
        XCTAssertNil(session.authToken)
        XCTAssertNil(session.userId)
    }

    func testLoginPersistsAndFlipsState() {
        session.login(token: "tok", refreshToken: "ref", userId: "42")
        XCTAssertTrue(session.isLoggedIn)
        XCTAssertEqual(session.authToken, "tok")
        XCTAssertEqual(session.refreshToken, "ref")
        XCTAssertEqual(session.userId, "42")
        XCTAssertTrue(settings.teslaLinked)
    }

    func testLogoutClearsEverything() {
        session.login(token: "tok", refreshToken: "ref", userId: "42")
        session.logout()
        XCTAssertFalse(session.isLoggedIn)
        XCTAssertNil(session.authToken)
        XCTAssertNil(session.refreshToken)
        XCTAssertNil(session.userId)
        XCTAssertFalse(settings.teslaLinked)
    }

    func testIsLoggedInRequiresAllThreeBitsSet() {
        // Token + userId set but Tesla flag not flipped — still considered logged out.
        storage.authToken = "tok"
        storage.userId = "42"
        let s = AuthSession(secureStorage: storage, settings: settings)
        XCTAssertFalse(s.isLoggedIn)

        settings.teslaLinked = true
        let s2 = AuthSession(secureStorage: storage, settings: settings)
        XCTAssertTrue(s2.isLoggedIn)

        // Empty string user_id is not a valid login.
        storage.userId = ""
        let s3 = AuthSession(secureStorage: storage, settings: settings)
        XCTAssertFalse(s3.isLoggedIn)
    }

    func testUpdateAccessTokenKeepsUserLoggedIn() {
        session.login(token: "old", refreshToken: "r1", userId: "42")
        session.updateAccessToken("new", refreshToken: "r2")
        XCTAssertTrue(session.isLoggedIn)
        XCTAssertEqual(session.authToken, "new")
        XCTAssertEqual(session.refreshToken, "r2")
    }

    func testUpdateAccessTokenWithoutRefreshKeepsExisting() {
        session.login(token: "old", refreshToken: "r1", userId: "42")
        session.updateAccessToken("new", refreshToken: nil)
        XCTAssertEqual(session.authToken, "new")
        XCTAssertEqual(session.refreshToken, "r1")
    }
}

/// In-memory SettingsStore used only in tests. Does NOT belong in the
/// shipping library — it has no persistence, so it would silently
/// "forget" everything when re-instantiated.
final class InMemorySettingsStore: SettingsStore {
    var teslaLinked: Bool = false
    var targetArrivalSoc: Int = 20
    var minChargingSoc: Int = 10
    var preferSupercharger: Bool = true
    var distanceUnit: DistanceUnit = .kilometers

    func reset() {
        teslaLinked = false
        targetArrivalSoc = 20
        minChargingSoc = 10
        preferSupercharger = true
        distanceUnit = .kilometers
    }
}
