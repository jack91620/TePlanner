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
    func lockVehicle(vehicleId: String) async -> Result<BaseResponse, APIError>
    func unlockVehicle(vehicleId: String) async -> Result<BaseResponse, APIError>
    func setChargeLimit(vehicleId: String, percent: Int) async -> Result<BaseResponse, APIError>

    /// Generic capability dispatch. Used by Hub Quick Actions which
    /// let users build a button that invokes any registered Tesla
    /// capability with arbitrary params. Backend `/vehicles/{id}/invoke`
    /// validates against the capability registry; unknown ids surface
    /// as APIError.
    func invokeCapability(
        vehicleId: String,
        capability: String,
        params: [String: JSONValue]
    ) async -> Result<BaseResponse, APIError>

    // User settings (Phase A.5) — single JSON-blob bag keyed per user.
    // Hub Quick Actions ride on this (keys `hub.actions` + `hub.slots`),
    // as will route-planning preferences once they migrate off the
    // legacy iOS-only UserDefaults path.
    func getUserSettings() async -> Result<[String: JSONValue], APIError>
    /// PUT merges supplied keys into the user's settings bag. Pass
    /// `replaceAll: true` to wipe + re-seed (used by sign-out cleanup).
    func putUserSettings(
        _ settings: [String: JSONValue],
        replaceAll: Bool
    ) async -> Result<[String: JSONValue], APIError>

    // Charging stations
    func getNearbyStations(latitude: Double, longitude: Double, radiusKm: Int, type: String?) async -> Result<[ChargingStation], APIError>

    // Saved routes (history)
    func getRecentRoutes(limit: Int, offset: Int) async -> Result<RecentRoutesResponse, APIError>
    /// Persist a planned route to the user's 最近 list after the
    /// destination has been pushed to the car. The 最近 tab has no
    /// other write path — without this call, history is permanently
    /// empty. Best-effort: caller treats a failure as a non-fatal
    /// warning (Tesla nav already succeeded; we just lost the row).
    func saveRoutePlan(_ request: SaveRoutePlanRequest) async -> Result<SaveRoutePlanResponse, APIError>

    // Push notifications
    /// Hand the iOS APNs device token to the backend so the polling
    /// layer can deliver automation alerts when the app is closed.
    func registerDeviceToken(_ token: String, bundleId: String?) async -> Result<BaseResponse, APIError>

    // Shares — cross-platform 6-char code for one automation rule
    // or one hub quick action. Backend at /api/v1/shares.
    /// Mint a share code. Caller has already stripped user-scoped
    /// fields from `payload` (no user_id, no vehicle_id, no internal
    /// action_id). `minAppVersion` records the CFBundleVersion the
    /// share was authored against — older importers will see 412.
    func createShare(
        type: ShareType,
        payload: [String: JSONValue],
        expiresInDays: Int,
        minAppVersion: String?,
    ) async -> Result<ShareDetailResponse, APIError>
    /// Resolve a share code into the typed payload. Server normalizes
    /// case + dashes + whitespace so the caller can pass user input
    /// as-typed. Returns 404 / 410 / 412 via APIError as appropriate.
    func lookupShare(code: String) async -> Result<ShareDetailResponse, APIError>
    /// Owner-only revoke. 404 from server is mapped through.
    func revokeShare(code: String) async -> Result<Void, APIError>
    func listMyShares() async -> Result<ShareListResponse, APIError>

    // Automation rules
    func listAutomations() async -> Result<[RuleRecord], APIError>
    func createAutomation(name: String, enabled: Bool, spec: RuleSpec) async -> Result<RuleRecord, APIError>
    func updateAutomation(id: String, name: String?, enabled: Bool?, spec: RuleSpec?) async -> Result<RuleRecord, APIError>
    func deleteAutomation(id: String) async -> Result<BaseResponse, APIError>
    func listCapabilities() async -> Result<[CapabilityInfo], APIError>
    func fetchAutomationState() async -> Result<TelemetryStateResponse, APIError>
    func fetchPendingCommands() async -> Result<PendingCommandListResponse, APIError>
    func fetchQueuedCommands() async -> Result<QueuedCommandListResponse, APIError>
    func cancelQueuedCommand(id: Int) async -> Result<BaseResponse, APIError>
    func fetchRecentFires(limit: Int) async -> Result<RecentFiresResponse, APIError>

    // Phase D.1 — server-canonical snoozes. Replaces the iOS-side
    // UserDefaults `rule_snooze_until` map.
    /// Snooze ``ruleId``. Provide exactly one of ``hours`` (relative
    /// from now) or ``until`` (absolute UTC). Server enforces the XOR
    /// and returns 400 if both/neither are supplied.
    func snoozeRule(
        ruleId: String, hours: Double?, until: Date?, reason: String?
    ) async -> Result<SnoozeRecord, APIError>
    func unsnoozeRule(ruleId: String) async -> Result<BaseResponse, APIError>
    func fetchSnoozes() async -> Result<SnoozeListResponse, APIError>

    // Phase D.2 — server-canonical rule order. Replaces the iOS-side
    // UserDefaults `automation_rule_order` array. Returns the full
    // sorted rule list so callers can replace their cache in one
    // round-trip (avoids an extra GET).
    func reorderAutomations(
        ruleIds: [String], clear: Bool
    ) async -> Result<[RuleRecord], APIError>

    // Phase D.3 — server-canonical scheduled departure. Replaces
    // UserDefaultsScheduledDepartureStore.
    /// Returns nil when the user has no row.
    func fetchScheduledDeparture() async -> Result<ScheduledDepartureResponse?, APIError>
    func upsertScheduledDeparture(
        _ departure: ScheduledDeparture
    ) async -> Result<ScheduledDepartureResponse, APIError>
    func clearScheduledDeparture() async -> Result<BaseResponse, APIError>

    // Phase D.4 — server-canonical charging sessions. Replaces
    // UserDefaultsChargingSessionStore.
    func upsertChargingSession(
        vehicleId: String, request: ChargingSessionRequest
    ) async -> Result<ChargingSessionResponse, APIError>
    func listChargingSessions(
        vehicleId: String, limit: Int
    ) async -> Result<ChargingSessionListResponse, APIError>

    // Phase D.5 — server-canonical charge-limit suggestion. Backend
    // reads the user's ScheduledDeparture (A.3 store) so iOS only has
    // to pass current limit + daily / trip preferences.
    func suggestChargeLimit(
        vehicleId: String, request: SuggestChargeLimitRequest
    ) async -> Result<SuggestChargeLimitResponse, APIError>
}
