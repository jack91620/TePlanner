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

    func testUnbindCallsAPIAndLogsOut() async {
        session.login(token: "tok", refreshToken: "ref", userId: "42")
        let api = MockAPIService()
        api.mockUnbindTeslaResponse = .success(BaseResponse(success: true, message: "ok"))

        let result = await session.unbindTesla(api: api)

        XCTAssertEqual(api.unbindTeslaCallCount, 1)
        XCTAssertFalse(session.isLoggedIn, "local creds should be cleared")
        XCTAssertNil(session.authToken)
        if case .failure = result { XCTFail("expected success") }
    }

    func testUnbindStillLogsOutEvenWhenServerFails() async {
        session.login(token: "tok", refreshToken: "ref", userId: "42")
        let api = MockAPIService()
        api.mockUnbindTeslaResponse = .failure(.serverError(statusCode: 500, message: "boom"))

        let result = await session.unbindTesla(api: api)

        XCTAssertFalse(session.isLoggedIn, "local creds should still be cleared on server error")
        if case .success = result { XCTFail("expected failure") }
    }

    func testUnbindWithoutUserIdShortCircuits() async {
        // Fresh session — no logged-in user.
        let api = MockAPIService()
        let result = await session.unbindTesla(api: api)

        XCTAssertEqual(api.unbindTeslaCallCount, 0, "should not hit API without a user_id")
        if case .failure = result { XCTFail("no-op should be success") }
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
    var campModeReminderMinutes: Int = 120
    var sentryReminderMinutes: Int = 1440
    var cabinOverheatReminderMinutes: Int = 60
    var chargeCompleteReminderEnabled: Bool = true
    var dailyChargeLimitSoc: Int = 70
    var tripChargeLimitSoc: Int = 90
    var hasPromptedVCPPairing: Bool = false
    var hasSeenHubWelcome: Bool = false

    func reset() {
        teslaLinked = false
        targetArrivalSoc = 20
        minChargingSoc = 10
        preferSupercharger = true
        distanceUnit = .kilometers
        campModeReminderMinutes = 120
        sentryReminderMinutes = 1440
        cabinOverheatReminderMinutes = 60
        chargeCompleteReminderEnabled = true
        dailyChargeLimitSoc = 70
        tripChargeLimitSoc = 90
        hasPromptedVCPPairing = false
        hasSeenHubWelcome = false
    }
}
