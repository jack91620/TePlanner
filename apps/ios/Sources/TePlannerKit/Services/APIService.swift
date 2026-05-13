import Foundation

public final class APIService: APIServiceProtocol {
    public static let shared = APIService(baseURL: APIService.bundleBackendURL ?? "http://127.0.0.1:8000/api/v1")

    /// Posted whenever the backend rejects our session token (HTTP 401).
    /// AuthSession listens for this and forces a logout so the user is
    /// kicked back to LoginView instead of staring at silent failures.
    public static let unauthorizedNotification = Notification.Name("APIServiceUnauthorized")

    private let baseURL: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let tokenProvider: () -> String?

    public init(
        baseURL: String = "http://127.0.0.1:8000/api/v1",
        session: URLSession = .shared,
        tokenProvider: @escaping () -> String? = { KeychainStorage.shared.authToken }
    ) {
        self.baseURL = baseURL
        self.session = session
        let enc = JSONEncoder()
        // Phase D.1 — ISO 8601 so `Date` fields (e.g. snooze `until`)
        // serialize to FastAPI's expected datetime string. No prior
        // POST body included a Date field, so this change is additive
        // and safe for existing endpoints.
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom(APIService.decodePydanticDate)
        self.decoder = dec
        self.tokenProvider = tokenProvider
    }

    /// Pydantic v2 emits dates in five ish flavors and Apple's
    /// strict ISO8601 doesn't cover all of them. Try in order:
    ///   1. ISO 8601 with fractional + tz: ``2026-05-08T07:55:40.123Z``
    ///   2. ISO 8601 with tz, no fractional: ``2026-05-08T07:55:40+00:00``
    ///   3. Plain ``yyyy-MM-dd'T'HH:mm:ss`` (no tz, no fractional)
    ///   4. Plain w/ fractional stripped: ``2026-05-09T09:26:35.704923``
    ///      → re-try (3) on the prefix before the dot. Microsecond
    ///      precision isn't load-bearing for snooze/audit fields.
    /// Exposed `internal` so tests can validate every shape without
    /// going through APIService.init's URLSession plumbing.
    static func decodePydanticDate(decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let s = try container.decode(String.self)
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFractional.date(from: s) { return d }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }
        let plain = DateFormatter()
        plain.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        plain.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = plain.date(from: s) { return d }
        if let dot = s.firstIndex(of: ".") {
            let truncated = String(s[..<dot])
            if let d = plain.date(from: truncated) { return d }
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unrecognized date format: \(s)"
        )
    }

    private static var bundleBackendURL: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "BackendURL") as? String,
              !raw.isEmpty else { return nil }
        return raw
    }

    // MARK: - Routes / geocoding

    public func routeOnly(origin: LocationInput, destination: LocationInput) async -> Result<RouteOnlyResponse, APIError> {
        let body = RouteOnlyRequest(origin: origin, destination: destination)
        return await postJSON(path: "/routes/route", body: body)
    }

    public func chargingPlan(_ request: ChargingPlanRequest) async -> Result<ChargingPlanResponse, APIError> {
        return await postJSON(path: "/routes/charging-plan", body: request)
    }

    public func geocode(address: String) async -> Result<GeocodeResponse, APIError> {
        return await postJSON(path: "/routes/geocode", body: GeocodeRequest(address: address))
    }

    public func reverseGeocode(latitude: Double, longitude: Double) async -> Result<ReverseGeocodeResponse, APIError> {
        // Backend's POST /routes/reverse-geocode takes `latitude` and
        // `longitude` as query parameters (no JSON body).
        let query = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
        ]
        return await post(path: "/routes/reverse-geocode", query: query)
    }

    // MARK: - Tesla OAuth

    public func getTeslaAuthUrl() async -> Result<TeslaAuthUrlResponse, APIError> {
        return await get(path: "/auth/tesla/authorize")
    }

    public func checkTeslaStatus(userId: String) async -> Result<TeslaStatusResponse, APIError> {
        return await get(path: "/auth/tesla/status", query: [URLQueryItem(name: "user_id", value: userId)])
    }

    public func unbindTesla(userId: String) async -> Result<BaseResponse, APIError> {
        return await post(path: "/auth/tesla/unbind", query: [URLQueryItem(name: "user_id", value: userId)])
    }

    // MARK: - Auth

    public func validateToken() async -> Result<AuthValidationResponse, APIError> {
        return await get(path: "/auth/validate")
    }

    public func refreshToken(_ refreshToken: String) async -> Result<AuthResponse, APIError> {
        return await postJSON(path: "/auth/refresh", body: RefreshTokenRequest(refreshToken: refreshToken))
    }

    // MARK: - Vehicles

    public func getVehicles(userId: String) async -> Result<VehiclesResponse, APIError> {
        return await get(path: "/vehicles/", query: [URLQueryItem(name: "user_id", value: userId)])
    }

    public func getVehicleState(vehicleId: String, userId: String) async -> Result<VehicleState, APIError> {
        return await get(path: "/vehicles/\(vehicleId)/state", query: [URLQueryItem(name: "user_id", value: userId)])
    }

    public func wakeVehicle(vehicleId: String, userId: String) async -> Result<WakeResponse, APIError> {
        return await post(path: "/vehicles/\(vehicleId)/wake", query: [URLQueryItem(name: "user_id", value: userId)])
    }

    public func sendNavigation(vehicleId: String, request: NavigationRequest) async -> Result<BaseResponse, APIError> {
        return await postJSON(path: "/vehicles/\(vehicleId)/navigate", body: request)
    }

    public func setClimateKeeperMode(vehicleId: String, mode: Int) async -> Result<BaseResponse, APIError> {
        struct Body: Encodable { let mode: Int }
        return await postJSON(path: "/vehicles/\(vehicleId)/climate-keeper-mode", body: Body(mode: mode))
    }

    public func setSentryMode(vehicleId: String, on: Bool) async -> Result<BaseResponse, APIError> {
        struct Body: Encodable { let on: Bool }
        return await postJSON(path: "/vehicles/\(vehicleId)/sentry-mode", body: Body(on: on))
    }

    public func preheat(vehicleId: String) async -> Result<BaseResponse, APIError> {
        return await post(path: "/vehicles/\(vehicleId)/preheat")
    }

    public func lockVehicle(vehicleId: String) async -> Result<BaseResponse, APIError> {
        return await post(path: "/vehicles/\(vehicleId)/lock")
    }

    public func unlockVehicle(vehicleId: String) async -> Result<BaseResponse, APIError> {
        return await post(path: "/vehicles/\(vehicleId)/unlock")
    }

    public func setChargeLimit(vehicleId: String, percent: Int) async -> Result<BaseResponse, APIError> {
        struct Body: Encodable { let percent: Int }
        return await postJSON(path: "/vehicles/\(vehicleId)/charge-limit", body: Body(percent: percent))
    }

    public func invokeCapability(
        vehicleId: String,
        capability: String,
        params: [String: JSONValue]
    ) async -> Result<BaseResponse, APIError> {
        struct Body: Encodable {
            let capability: String
            let params: [String: JSONValue]
        }
        return await postJSON(
            path: "/vehicles/\(vehicleId)/invoke",
            body: Body(capability: capability, params: params),
        )
    }

    // MARK: - User settings

    public func getUserSettings() async -> Result<[String: JSONValue], APIError> {
        struct Resp: Decodable {
            let settings: [String: JSONValue]
        }
        let result: Result<Resp, APIError> = await get(path: "/user/settings", query: [])
        return result.map { $0.settings }
    }

    public func putUserSettings(
        _ settings: [String: JSONValue],
        replaceAll: Bool = false
    ) async -> Result<[String: JSONValue], APIError> {
        struct Body: Encodable {
            let settings: [String: JSONValue]
            let replace_all: Bool
        }
        struct Resp: Decodable {
            let settings: [String: JSONValue]
        }
        let result: Result<Resp, APIError> = await putJSON(
            path: "/user/settings",
            body: Body(settings: settings, replace_all: replaceAll),
        )
        return result.map { $0.settings }
    }

    // MARK: - Charging stations

    public func getNearbyStations(latitude: Double, longitude: Double, radiusKm: Int = 50, type: String? = nil) async -> Result<[ChargingStation], APIError> {
        var query = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radiusKm))
        ]
        if let type {
            query.append(URLQueryItem(name: "type", value: type))
        }
        let response: Result<NearbyChargingResponse, APIError> = await get(path: "/charging/nearby", query: query)
        return response.map { $0.stations }
    }

    public func getRecentRoutes(limit: Int = 10, offset: Int = 0) async -> Result<RecentRoutesResponse, APIError> {
        let query = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        return await get(path: "/routes/", query: query)
    }

    public func saveRoutePlan(_ request: SaveRoutePlanRequest) async -> Result<SaveRoutePlanResponse, APIError> {
        return await postJSON(path: "/routes/save", body: request)
    }

    // MARK: - Active trip (sequential multi-stop nav)

    /// Kick off a multi-stop trip. Cancels any existing active trip
    /// for this user. Backend sends stops[0] to the car immediately.
    public func startTrip(_ request: StartTripRequest) async -> Result<ActiveTrip, APIError> {
        return await postJSON(path: "/trips/start", body: request)
    }

    /// User's currently-active trip, or nil. Drives the Hub
    /// "进行中行程" card. Backend returns literal `null` when there's
    /// no trip — JSONDecoder rejects that at the top level, so we
    /// short-circuit and treat empty / null body as `.success(nil)`.
    public func fetchActiveTrip() async -> Result<ActiveTrip?, APIError> {
        let result: Result<ActiveTripOrNull, APIError> = await get(
            path: "/trips/active", query: []
        )
        return result.map { $0.value }
    }

    /// Wrapper that decodes either a full ActiveTrip object or the
    /// literal `null` body /trips/active returns when nothing's
    /// active. Stays private to APIService — callers use the
    /// `ActiveTrip?` shape of fetchActiveTrip().
    private struct ActiveTripOrNull: Decodable {
        let value: ActiveTrip?
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                value = nil
            } else {
                value = try container.decode(ActiveTrip.self)
            }
        }
    }

    /// Push the next stop to the car. Returns the updated trip
    /// (status="completed" if we'd just sent the final stop).
    public func advanceTrip(_ tripId: Int) async -> Result<ActiveTrip, APIError> {
        return await post(path: "/trips/\(tripId)/advance")
    }

    /// Replace stops[current..] with new_stops; backend pushes the
    /// first new stop to the car with `reason` prepended to the
    /// address line so the car screen shows why the route changed.
    public func replanTrip(_ tripId: Int, request: ReplanTripRequest) async -> Result<ActiveTrip, APIError> {
        return await postJSON(path: "/trips/\(tripId)/replan", body: request)
    }

    public func cancelTrip(_ tripId: Int) async -> Result<ActiveTrip, APIError> {
        return await post(path: "/trips/\(tripId)/cancel")
    }

    // MARK: - Push notifications

    public func registerDeviceToken(_ token: String, bundleId: String?) async -> Result<BaseResponse, APIError> {
        struct Body: Encodable {
            let token: String
            let bundle_id: String?
        }
        return await postJSON(path: "/devices/register", body: Body(token: token, bundle_id: bundleId))
    }

    // MARK: - Automation rules

    private struct RuleListResponseDTO: Decodable {
        let rules: [RuleRecord]
    }

    // MARK: - Shares

    public func createShare(
        type: ShareType,
        payload: [String: JSONValue],
        expiresInDays: Int,
        minAppVersion: String?,
    ) async -> Result<ShareDetailResponse, APIError> {
        struct Body: Encodable {
            let share_type: String
            let payload: [String: JSONValue]
            let expires_in_days: Int
            let min_app_version: String?
        }
        return await postJSON(
            path: "/shares",
            body: Body(
                share_type: type.rawValue,
                payload: payload,
                expires_in_days: expiresInDays,
                min_app_version: minAppVersion,
            ),
        )
    }

    public func lookupShare(code: String) async -> Result<ShareDetailResponse, APIError> {
        // Server normalizes case + dashes; we still strip whitespace
        // locally so the URL doesn't get %20-encoded gunk.
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return await get(path: "/shares/\(trimmed)")
    }

    public func revokeShare(code: String) async -> Result<Void, APIError> {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return await deleteVoid(path: "/shares/\(trimmed)")
    }

    public func listMyShares() async -> Result<ShareListResponse, APIError> {
        return await get(path: "/shares/mine")
    }

    public func listAutomations() async -> Result<[RuleRecord], APIError> {
        let result: Result<RuleListResponseDTO, APIError> = await get(path: "/automations/")
        switch result {
        case .success(let dto): return .success(dto.rules)
        case .failure(let err): return .failure(err)
        }
    }

    public func createAutomation(name: String, enabled: Bool, spec: RuleSpec) async -> Result<RuleRecord, APIError> {
        struct Body: Encodable {
            let name: String
            let enabled: Bool
            let spec: RuleSpec
        }
        return await postJSON(path: "/automations/", body: Body(name: name, enabled: enabled, spec: spec))
    }

    public func updateAutomation(id: String, name: String?, enabled: Bool?, spec: RuleSpec?) async -> Result<RuleRecord, APIError> {
        struct Body: Encodable {
            let name: String?
            let enabled: Bool?
            let spec: RuleSpec?
        }
        return await putJSON(path: "/automations/\(id)", body: Body(name: name, enabled: enabled, spec: spec))
    }

    public func deleteAutomation(id: String) async -> Result<BaseResponse, APIError> {
        return await delete(path: "/automations/\(id)")
    }

    private struct CapabilityListDTO: Decodable {
        let capabilities: [CapabilityInfo]
    }

    public func listCapabilities() async -> Result<[CapabilityInfo], APIError> {
        let r: Result<CapabilityListDTO, APIError> = await get(path: "/automations/capabilities")
        switch r {
        case .success(let dto): return .success(dto.capabilities)
        case .failure(let e): return .failure(e)
        }
    }

    public func fetchAutomationState() async -> Result<TelemetryStateResponse, APIError> {
        return await get(path: "/automations/state")
    }

    // MARK: - Phase 9 + 10 — command status / queue (sleep-aware)

    public func fetchPendingCommands() async -> Result<PendingCommandListResponse, APIError> {
        return await get(path: "/vehicles/commands/pending")
    }

    public func fetchQueuedCommands() async -> Result<QueuedCommandListResponse, APIError> {
        return await get(path: "/vehicles/commands/queued")
    }

    public func cancelQueuedCommand(id: Int) async -> Result<BaseResponse, APIError> {
        return await delete(path: "/vehicles/commands/queued/\(id)")
    }

    public func fetchRecentFires(limit: Int = 50) async -> Result<RecentFiresResponse, APIError> {
        return await get(path: "/automations/recent-fires?limit=\(limit)")
    }

    // MARK: - Phase D.1 — snoozes

    public func snoozeRule(
        ruleId: String, hours: Double?, until: Date?, reason: String?
    ) async -> Result<SnoozeRecord, APIError> {
        struct Body: Encodable {
            let hours: Double?
            let until: Date?
            let reason: String?
        }
        return await postJSON(
            path: "/automations/\(ruleId)/snooze",
            body: Body(hours: hours, until: until, reason: reason),
        )
    }

    public func unsnoozeRule(ruleId: String) async -> Result<BaseResponse, APIError> {
        return await delete(path: "/automations/\(ruleId)/snooze")
    }

    public func fetchSnoozes() async -> Result<SnoozeListResponse, APIError> {
        return await get(path: "/automations/snoozes")
    }

    // MARK: - Phase D.2 — rule order

    public func reorderAutomations(
        ruleIds: [String], clear: Bool
    ) async -> Result<[RuleRecord], APIError> {
        struct Body: Encodable {
            let rule_ids: [String]
            let clear: Bool
        }
        // Server returns RuleListResponse { rules: [...] } — unwrap.
        let result: Result<RuleListResponseDTO, APIError> = await putJSON(
            path: "/automations/order",
            body: Body(rule_ids: ruleIds, clear: clear),
        )
        return result.map { $0.rules }
    }

    // MARK: - Phase D.3 — scheduled departure

    public func fetchScheduledDeparture() async -> Result<ScheduledDepartureResponse?, APIError> {
        // Server returns either a body or top-level `null` when the
        // user has no row. JSONDecoder handles optional unwrap natively
        // for `Optional<Decodable>` so a single get<...?> works.
        return await get(path: "/user/scheduled-departure")
    }

    public func upsertScheduledDeparture(
        _ departure: ScheduledDeparture
    ) async -> Result<ScheduledDepartureResponse, APIError> {
        return await putJSON(
            path: "/user/scheduled-departure",
            body: ScheduledDepartureRequest(departure),
        )
    }

    public func clearScheduledDeparture() async -> Result<BaseResponse, APIError> {
        return await delete(path: "/user/scheduled-departure")
    }

    // MARK: - Phase D.4 — charging sessions

    public func upsertChargingSession(
        vehicleId: String, request: ChargingSessionRequest
    ) async -> Result<ChargingSessionResponse, APIError> {
        return await postJSON(
            path: "/vehicles/\(vehicleId)/sessions",
            body: request,
        )
    }

    public func listChargingSessions(
        vehicleId: String, limit: Int = 50
    ) async -> Result<ChargingSessionListResponse, APIError> {
        return await get(path: "/vehicles/\(vehicleId)/sessions?limit=\(limit)")
    }

    // MARK: - Phase D.5 — charge-limit suggestion

    public func suggestChargeLimit(
        vehicleId: String, request: SuggestChargeLimitRequest
    ) async -> Result<SuggestChargeLimitResponse, APIError> {
        return await postJSON(
            path: "/vehicles/\(vehicleId)/suggest-charge-limit",
            body: request,
        )
    }

    // MARK: - Internals

    private func get<T: Decodable>(path: String, query: [URLQueryItem] = []) async -> Result<T, APIError> {
        guard let url = makeURL(path: path, query: query) else { return .failure(.invalidURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return await perform(req)
    }

    private func post<T: Decodable>(path: String, query: [URLQueryItem] = []) async -> Result<T, APIError> {
        guard let url = makeURL(path: path, query: query) else { return .failure(.invalidURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        return await perform(req)
    }

    private func postJSON<Body: Encodable, T: Decodable>(path: String, body: Body, query: [URLQueryItem] = []) async -> Result<T, APIError> {
        guard let url = makeURL(path: path, query: query) else { return .failure(.invalidURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            req.httpBody = try encoder.encode(body)
        } catch {
            return .failure(.decodingError(error))
        }
        return await perform(req)
    }

    private func putJSON<Body: Encodable, T: Decodable>(path: String, body: Body, query: [URLQueryItem] = []) async -> Result<T, APIError> {
        guard let url = makeURL(path: path, query: query) else { return .failure(.invalidURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            req.httpBody = try encoder.encode(body)
        } catch {
            return .failure(.decodingError(error))
        }
        return await perform(req)
    }

    private func delete<T: Decodable>(path: String, query: [URLQueryItem] = []) async -> Result<T, APIError> {
        guard let url = makeURL(path: path, query: query) else { return .failure(.invalidURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        return await perform(req)
    }

    /// DELETE / 204 No Content variant — for endpoints whose success
    /// response has an empty body. The generic `delete<T>` above
    /// would 500 with a decoding error since there's no JSON to
    /// parse. Shares' revoke endpoint is the first user; future
    /// 204-returning endpoints should reuse this.
    private func deleteVoid(path: String, query: [URLQueryItem] = []) async -> Result<Void, APIError> {
        guard let url = makeURL(path: path, query: query) else { return .failure(.invalidURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        return await performVoid(req)
    }

    private func performVoid(_ request: URLRequest) async -> Result<Void, APIError> {
        let method = request.httpMethod ?? "?"
        let path = request.url?.path ?? "?"
        let started = Date()
        Log.api.debug("→ \(method, privacy: .public) \(path, privacy: .public)")

        var authedRequest = request
        if authedRequest.value(forHTTPHeaderField: "Authorization") == nil,
           let token = tokenProvider(),
           !token.isEmpty {
            authedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: authedRequest)
            let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
            guard let http = response as? HTTPURLResponse else {
                Log.api.error("← \(method, privacy: .public) \(path, privacy: .public) non-HTTP response")
                return .failure(.invalidResponse)
            }
            Log.api.debug("← \(method, privacy: .public) \(path, privacy: .public) \(http.statusCode) in \(elapsedMs)ms (\(data.count) bytes)")

            guard (200...299).contains(http.statusCode) else {
                let bodyPreview = String(data: data.prefix(512), encoding: .utf8) ?? "<binary>"
                Log.api.error("server error \(http.statusCode) on \(path, privacy: .public): \(bodyPreview, privacy: .public)")
                if http.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                }
                let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
                return .failure(.serverError(statusCode: http.statusCode, message: message))
            }
            return .success(())
        } catch {
            Log.api.error("request \(method, privacy: .public) \(path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return .failure(.requestFailed(error))
        }
    }

    private func makeURL(path: String, query: [URLQueryItem]) -> URL? {
        var components = URLComponents(string: baseURL + path)
        if !query.isEmpty {
            components?.queryItems = query
        }
        return components?.url
    }

    private func perform<T: Decodable>(_ request: URLRequest) async -> Result<T, APIError> {
        let method = request.httpMethod ?? "?"
        let path = request.url?.path ?? "?"
        let started = Date()
        Log.api.debug("→ \(method, privacy: .public) \(path, privacy: .public)")

        var authedRequest = request
        if authedRequest.value(forHTTPHeaderField: "Authorization") == nil,
           let token = tokenProvider(),
           !token.isEmpty {
            authedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: authedRequest)
            let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
            guard let http = response as? HTTPURLResponse else {
                Log.api.error("← \(method, privacy: .public) \(path, privacy: .public) non-HTTP response")
                return .failure(.invalidResponse)
            }
            Log.api.debug("← \(method, privacy: .public) \(path, privacy: .public) \(http.statusCode) in \(elapsedMs)ms (\(data.count) bytes)")

            guard (200...299).contains(http.statusCode) else {
                let bodyPreview = String(data: data.prefix(512), encoding: .utf8) ?? "<binary>"
                Log.api.error("server error \(http.statusCode) on \(path, privacy: .public): \(bodyPreview, privacy: .public)")
                if http.statusCode == 401 {
                    NotificationCenter.default.post(name: APIService.unauthorizedNotification, object: nil)
                }
                let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
                return .failure(.serverError(statusCode: http.statusCode, message: message))
            }
            do {
                return .success(try decoder.decode(T.self, from: data))
            } catch {
                let bodyPreview = String(data: data.prefix(512), encoding: .utf8) ?? "<binary>"
                Log.api.error("decode error on \(path, privacy: .public) for \(String(describing: T.self), privacy: .public): \(error.localizedDescription, privacy: .public) — body: \(bodyPreview, privacy: .public)")
                return .failure(.decodingError(error))
            }
        } catch {
            Log.api.error("request \(method, privacy: .public) \(path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return .failure(.requestFailed(error))
        }
    }
}
