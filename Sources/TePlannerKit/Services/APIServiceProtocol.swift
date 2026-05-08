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
        case .serverError(let statusCode, let message):
            // Tesla 2023-10-09 废弃了旧 REST 车辆命令端点，所有
            // set_charge_limit / set_climate_keeper_mode / sentry / preheat
            // 命令需迁移到新的 Vehicle Command Protocol (VCP)。在我们
            // 后端完成代理迁移之前，把这个 403 转成中文友好提示，避免
            // 用户看到一长串 Tesla SDK 报错。
            if statusCode == 403 && message.contains("Vehicle Command Protocol") {
                return "Tesla 已升级车辆命令协议，此功能正在迁移中。请在 Tesla 官方 App 内手动操作。"
            }
            return "服务器错误 (\(statusCode)): \(message)"
        }
    }

    /// `true` 当此错误是 Tesla VCP 迁移引起的、当前所有 vehicle
    /// command action 都暂时不可用。UI 可以基于此预先 disable 按钮
    /// 而不是等用户点了再报错。
    public var isTeslaVCPRequired: Bool {
        if case .serverError(let statusCode, let message) = self,
           statusCode == 403,
           message.contains("Vehicle Command Protocol") {
            return true
        }
        return false
    }
}

public protocol APIServiceProtocol {
    // Routes / geocoding
    /// Route metadata only (polyline + distance). Used by the iOS-
    /// orchestrated flow alongside /routes/charging-plan.
    func routeOnly(origin: LocationInput, destination: LocationInput) async -> Result<RouteOnlyResponse, APIError>
    /// Greedy charging-stop selection over caller-provided POIs
    /// (from AMap iOS SDK along-route search).
    func chargingPlan(_ request: ChargingPlanRequest) async -> Result<ChargingPlanResponse, APIError>
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
    func setChargeLimit(vehicleId: String, percent: Int) async -> Result<BaseResponse, APIError>

    // Charging stations
    func getStationDetail(stationId: String) async -> Result<ChargingStation, APIError>
    func getNearbyStations(latitude: Double, longitude: Double, radiusKm: Int, type: String?) async -> Result<[ChargingStation], APIError>

    // Saved routes (history)
    func getRecentRoutes(limit: Int, offset: Int) async -> Result<RecentRoutesResponse, APIError>

    // Push notifications
    /// Hand the iOS APNs device token to the backend so the polling
    /// layer can deliver automation alerts when the app is closed.
    func registerDeviceToken(_ token: String, bundleId: String?) async -> Result<BaseResponse, APIError>

    // Automation rules
    func listAutomations() async -> Result<[RuleRecord], APIError>
    func createAutomation(name: String, enabled: Bool, spec: RuleSpec) async -> Result<RuleRecord, APIError>
    func updateAutomation(id: String, name: String?, enabled: Bool?, spec: RuleSpec?) async -> Result<RuleRecord, APIError>
    func deleteAutomation(id: String) async -> Result<BaseResponse, APIError>
    func listCapabilities() async -> Result<[CapabilityInfo], APIError>
}
