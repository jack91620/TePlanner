import XCTest
@testable import TePlannerKit

@MainActor
final class LoginViewModelTests: XCTestCase {
    private var api: MockAPIService!
    private var storage: InMemorySecureStorage!
    private var settings: InMemorySettingsStore!
    private var session: AuthSession!
    private var vm: LoginViewModel!

    override func setUp() async throws {
        api = MockAPIService()
        storage = InMemorySecureStorage()
        settings = InMemorySettingsStore()
        session = AuthSession(secureStorage: storage, settings: settings)
        vm = LoginViewModel(apiService: api, authSession: session, secureStorage: storage)
    }

    // MARK: - parseCallback

    func testParseCallbackHandlesPlainJSON() {
        let json = #"{"token":"abc.def.ghi","refresh_token":"r1","user_id":42}"#
        let parsed = LoginViewModel.parseCallback(pageContent: json)
        XCTAssertEqual(parsed?.token, "abc.def.ghi")
        XCTAssertEqual(parsed?.refreshToken, "r1")
        XCTAssertEqual(parsed?.userId, "42")
    }

    func testParseCallbackHandlesEscapedJSON() {
        let escaped = #"{\"token\":\"abc\",\"user_id\":\"15\"}"#
        let parsed = LoginViewModel.parseCallback(pageContent: escaped)
        XCTAssertEqual(parsed?.token, "abc")
        XCTAssertEqual(parsed?.userId, "15")
    }

    func testParseCallbackProbesAlternateTokenFields() {
        let withAccessToken = #"{"access_token":"xyz","user_id":1}"#
        XCTAssertEqual(LoginViewModel.parseCallback(pageContent: withAccessToken)?.token, "xyz")

        let withAuthToken = #"{"auth_token":"qqq","user_id":1}"#
        XCTAssertEqual(LoginViewModel.parseCallback(pageContent: withAuthToken)?.token, "qqq")
    }

    func testParseCallbackHandlesEmptyOrNonJSON() {
        XCTAssertNil(LoginViewModel.parseCallback(pageContent: nil))
        XCTAssertNil(LoginViewModel.parseCallback(pageContent: ""))
        XCTAssertNil(LoginViewModel.parseCallback(pageContent: "<html>not json</html>"))
    }

    // MARK: - start

    func testStartTransitionsToReadyOnSuccess() async {
        api.mockTeslaAuthUrlResponse = .success(
            TeslaAuthUrlResponse(url: "https://auth.tesla.com/oauth?client=x",
                                 state: "csrf-1",
                                 userId: 99)
        )
        await vm.start()
        guard case .ready(let url, let expected) = vm.state else {
            return XCTFail("Expected .ready, got \(vm.state)")
        }
        XCTAssertEqual(url.absoluteString, "https://auth.tesla.com/oauth?client=x")
        XCTAssertEqual(expected, "csrf-1")
        XCTAssertEqual(storage.userId, "99", "Preliminary user_id should be persisted before callback")
    }

    func testStartReportsFailureFromAPI() async {
        api.mockTeslaAuthUrlResponse = .failure(.invalidURL)
        await vm.start()
        guard case .failed = vm.state else {
            return XCTFail("Expected .failed, got \(vm.state)")
        }
    }

    // MARK: - handleCallback

    func testHandleCallbackHappyPathLogsIn() async {
        api.mockTeslaAuthUrlResponse = .success(
            TeslaAuthUrlResponse(url: "https://auth.tesla.com/oauth", state: "csrf-1", userId: 99)
        )
        await vm.start()

        vm.handleCallback(
            code: "code-xyz",
            state: "csrf-1",
            pageContent: #"{"token":"jwt-token","user_id":42}"#
        )

        XCTAssertEqual(vm.state, .success)
        XCTAssertTrue(session.isLoggedIn)
        XCTAssertEqual(session.authToken, "jwt-token")
        XCTAssertEqual(session.userId, "42")
    }

    func testHandleCallbackRejectsStateMismatch() async {
        api.mockTeslaAuthUrlResponse = .success(
            TeslaAuthUrlResponse(url: "https://auth.tesla.com/oauth", state: "csrf-1", userId: nil)
        )
        await vm.start()

        vm.handleCallback(
            code: "code-xyz",
            state: "csrf-WRONG",
            pageContent: #"{"token":"x","user_id":1}"#
        )

        guard case .failed(let msg) = vm.state else {
            return XCTFail("Expected .failed, got \(vm.state)")
        }
        XCTAssertTrue(msg.contains("安全验证"))
        XCTAssertFalse(session.isLoggedIn)
    }

    func testHandleCallbackFallsBackToPreliminaryUserId() async {
        api.mockTeslaAuthUrlResponse = .success(
            TeslaAuthUrlResponse(url: "https://auth.tesla.com/oauth", state: "csrf-1", userId: 77)
        )
        await vm.start()

        // Page omits user_id — viewModel should reuse the preliminary one
        // captured at start().
        vm.handleCallback(
            code: "c",
            state: "csrf-1",
            pageContent: #"{"token":"jwt"}"#
        )

        XCTAssertEqual(vm.state, .success)
        XCTAssertEqual(session.userId, "77")
    }

    func testHandleCallbackIsIdempotent() async {
        api.mockTeslaAuthUrlResponse = .success(
            TeslaAuthUrlResponse(url: "https://auth.tesla.com/oauth", state: "csrf-1", userId: 1)
        )
        await vm.start()

        vm.handleCallback(code: "c", state: "csrf-1", pageContent: #"{"token":"a","user_id":1}"#)
        let firstToken = session.authToken

        // Fire again with a different token — should be a no-op.
        vm.handleCallback(code: "c", state: "csrf-1", pageContent: #"{"token":"b","user_id":2}"#)
        XCTAssertEqual(session.authToken, firstToken)
    }
}
