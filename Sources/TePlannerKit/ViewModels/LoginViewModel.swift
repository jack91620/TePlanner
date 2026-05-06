import Foundation
import Combine

/// Drives the Tesla OAuth flow:
/// 1. Fetch auth URL + CSRF state from backend (`/auth/tesla/authorize`).
/// 2. Hand the URL to the platform WebView and remember the expected
///    state.
/// 3. When the WebView captures a callback URL with `code` + `state` and
///    extracts the JSON the backend embedded in the callback page, call
///    `handleCallback(...)`.
/// 4. Verify CSRF state, persist token + user id via `AuthSession`,
///    transition to `.success` so the UI can route to home.
///
/// Mirrors `VehicleBindingViewModel.kt` from the Android app.
@MainActor
public final class LoginViewModel: ObservableObject {
    public enum State: Equatable {
        case idle
        case loadingAuthUrl
        case ready(authUrl: URL, expectedState: String)
        case processingCallback
        case success
        case failed(message: String)
    }

    @Published public private(set) var state: State = .idle

    private let apiService: APIServiceProtocol
    private let authSession: AuthSession
    private let secureStorage: SecureStorage

    private var expectedState: String?
    private var preliminaryUserId: String?
    private var callbackProcessed = false

    public init(
        apiService: APIServiceProtocol,
        authSession: AuthSession,
        secureStorage: SecureStorage = KeychainStorage.shared
    ) {
        self.apiService = apiService
        self.authSession = authSession
        self.secureStorage = secureStorage
    }

    public func start() async {
        state = .loadingAuthUrl
        callbackProcessed = false

        let result = await apiService.getTeslaAuthUrl()
        switch result {
        case .success(let response):
            guard let url = URL(string: response.url) else {
                state = .failed(message: "服务器返回的授权URL无效")
                return
            }
            expectedState = response.state
            // For anonymous sessions the backend allocates a user_id up
            // front; remember it now so the callback can use it as a
            // fallback if the page content omits one.
            if let id = response.userId {
                preliminaryUserId = String(id)
                secureStorage.userId = String(id)
            }
            state = .ready(authUrl: url, expectedState: response.state)
        case .failure(let error):
            state = .failed(message: error.localizedDescription)
        }
    }

    public func handleCallback(code: String, state returnedState: String, pageContent: String?) {
        guard !callbackProcessed else { return }
        guard let expected = expectedState else {
            self.state = .failed(message: "状态校验失败，请重新登录")
            return
        }
        guard returnedState == expected else {
            self.state = .failed(message: "安全验证失败，请重试")
            return
        }
        callbackProcessed = true
        self.state = .processingCallback

        let parsed = Self.parseCallback(pageContent: pageContent)
        guard let token = parsed?.token else {
            self.state = .failed(message: "未能从登录回调中提取凭证")
            return
        }
        let resolvedUserId = parsed?.userId ?? preliminaryUserId
        guard let userId = resolvedUserId, !userId.isEmpty else {
            self.state = .failed(message: "未能识别用户ID")
            return
        }

        authSession.login(token: token, refreshToken: parsed?.refreshToken, userId: userId)
        self.state = .success
    }

    public func retry() {
        callbackProcessed = false
        Task { await start() }
    }

    // MARK: - Callback parsing

    struct ParsedCallback: Equatable {
        let token: String?
        let refreshToken: String?
        let userId: String?
    }

    /// Decodes the JSON blob the backend embeds in the callback HTML.
    /// Supports `token`/`access_token`/`auth_token` (Android also probes
    /// these three) and a `user_id` as either int or string.
    static func parseCallback(pageContent: String?) -> ParsedCallback? {
        guard let raw = pageContent?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        var jsonString = raw
        if jsonString.contains("\\\"") {
            jsonString = jsonString
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        guard jsonString.hasPrefix("{"), let data = jsonString.data(using: .utf8) else {
            return nil
        }
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let token = dict["token"] as? String
            ?? dict["access_token"] as? String
            ?? dict["auth_token"] as? String
        let refresh = dict["refresh_token"] as? String

        var userId: String?
        if let int = dict["user_id"] as? Int {
            userId = String(int)
        } else if let str = dict["user_id"] as? String {
            userId = str
        }

        return ParsedCallback(token: token, refreshToken: refresh, userId: userId)
    }
}
