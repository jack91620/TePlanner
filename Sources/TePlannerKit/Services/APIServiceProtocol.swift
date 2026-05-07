import Foundation

public enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的URL地址"
        case .requestFailed(let error): return "网络请求失败: \(error.localizedDescription)"
        case .invalidResponse: return "服务器返回无效数据"
        case .decodingError(let error): return "解析服务器数据失败: \(error.localizedDescription)"
        case .serverError(let statusCode, let message): return "服务器错误 (\(statusCode)): \(message)"
        }
    }
}

public protocol APIServiceProtocol {
    // Routes / geocoding (existing)
    func planRoute(origin: LocationInput?, destination: LocationInput, currentSoc: Int?) async -> Result<RoutePlanResponse, APIError>
    func geocode(address: String) async -> Result<GeocodeResponse, APIError>
    func reverseGeocode(latitude: Double, longitude: Double) async -> Result<ReverseGeocodeResponse, APIError>

    // Tesla OAuth
    func getTeslaAuthUrl() async -> Result<TeslaAuthUrlResponse, APIError>
    func checkTeslaStatus(userId: String) async -> Result<TeslaStatusResponse, APIError>
    func unbindTesla(userId: String) async -> Result<BaseResponse, APIError>

    // Auth
    func validateToken() async -> Result<AuthValidationResponse, APIError>
    func refreshToken(_ refreshToken: String) async -> Result<AuthResponse, APIError>

    // Vehicles
    func getVehicles(userId: String) async -> Result<VehiclesResponse, APIError>
    func getVehicleState(vehicleId: String, userId: String) async -> Result<VehicleState, APIError>
    func wakeVehicle(vehicleId: String, userId: String) async -> Result<WakeResponse, APIError>
    func sendNavigation(vehicleId: String, request: NavigationRequest) async -> Result<BaseResponse, APIError>
    func setClimateKeeperMode(vehicleId: String, mode: Int) async -> Result<BaseResponse, APIError>
    func setSentryMode(vehicleId: String, on: Bool) async -> Result<BaseResponse, APIError>
    func preheat(vehicleId: String) async -> Result<BaseResponse, APIError>

    // Charging stations
    func getStationDetail(stationId: String) async -> Result<ChargingStation, APIError>
    func getNearbyStations(latitude: Double, longitude: Double, radiusKm: Int, type: String?) async -> Result<[ChargingStation], APIError>

    // Saved routes (history)
    func getRecentRoutes(limit: Int, offset: Int) async -> Result<RecentRoutesResponse, APIError>
}
