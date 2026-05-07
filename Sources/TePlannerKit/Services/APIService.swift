import Foundation

public final class APIService: APIServiceProtocol {
    public static let shared = APIService(baseURL: APIService.bundleBackendURL ?? "http://127.0.0.1:8000/api/v1")

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
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.tokenProvider = tokenProvider
    }

    private static var bundleBackendURL: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "BackendURL") as? String,
              !raw.isEmpty else { return nil }
        return raw
    }

    // MARK: - Routes / geocoding

    public func planRoute(origin: LocationInput?, destination: LocationInput, currentSoc: Int?) async -> Result<RoutePlanResponse, APIError> {
        let body = RoutePlanRequest(origin: origin, destination: destination, vehicleId: nil, currentSoc: currentSoc)
        return await postJSON(path: "/routes/plan", body: body)
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

    // MARK: - Charging stations

    public func getStationDetail(stationId: String) async -> Result<ChargingStation, APIError> {
        return await get(path: "/charging/stations/\(stationId)")
    }

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
