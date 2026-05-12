import Foundation
@testable import TePlannerKit

/// Test mock — set the `mock*` properties before invoking. Each call site
/// records its invocation count for assertions.
final class MockAPIService: APIServiceProtocol {

    // Routes / geocoding
    var mockGeocodeResponse: Result<GeocodeResponse, APIError>!
    var mockReverseGeocodeResponse: Result<ReverseGeocodeResponse, APIError>!

    // Tesla OAuth
    var mockTeslaAuthUrlResponse: Result<TeslaAuthUrlResponse, APIError>!
    var mockTeslaStatusResponse: Result<TeslaStatusResponse, APIError>!
    var mockUnbindTeslaResponse: Result<BaseResponse, APIError>!

    // Auth
    var mockValidateTokenResponse: Result<AuthValidationResponse, APIError>!
    var mockRefreshTokenResponse: Result<AuthResponse, APIError>!

    // Vehicles
    var mockVehiclesResponse: Result<VehiclesResponse, APIError>!
    var mockVehicleStateResponse: Result<VehicleState, APIError>!
    /// If non-empty, each call to `getVehicleState` consumes the next entry
    /// (and the last entry sticks once the queue is exhausted). Useful for
    /// simulating "first probe fails, wake succeeds on Nth retry".
    var mockVehicleStateSequence: [Result<VehicleState, APIError>] = []
    var mockWakeVehicleResponse: Result<WakeResponse, APIError>!
    var mockSendNavigationResponse: Result<BaseResponse, APIError>!

    // Charging stations
    var mockNearbyStationsResponse: Result<[ChargingStation], APIError>!
    var mockRecentRoutesResponse: Result<RecentRoutesResponse, APIError>!

    // Call counts
    var geocodeCallCount = 0
    var reverseGeocodeCallCount = 0
    var lastReverseGeocodeArgs: (lat: Double, lng: Double)?
    var teslaAuthUrlCallCount = 0
    var teslaStatusCallCount = 0
    var unbindTeslaCallCount = 0
    var validateTokenCallCount = 0
    var refreshTokenCallCount = 0
    var getVehiclesCallCount = 0
    var getVehicleStateCallCount = 0
    var wakeVehicleCallCount = 0
    var sendNavigationCallCount = 0
    var nearbyStationsCallCount = 0
    var recentRoutesCallCount = 0

    // Last-args capture for arg-level assertions
    var lastNavigationRequest: NavigationRequest?
    var lastNearbyStationsArgs: (lat: Double, lng: Double, radius: Int, type: String?)?
    var lastRecentRoutesArgs: (limit: Int, offset: Int)?

    var mockRouteOnlyResponse: Result<RouteOnlyResponse, APIError>!
    var routeOnlyCallCount = 0
    func routeOnly(origin: LocationInput, destination: LocationInput) async -> Result<RouteOnlyResponse, APIError> {
        routeOnlyCallCount += 1
        return mockRouteOnlyResponse ?? .failure(.invalidResponse)
    }

    var mockChargingPlanResponse: Result<ChargingPlanResponse, APIError>!
    var chargingPlanCallCount = 0
    var lastChargingPlanRequest: ChargingPlanRequest?
    func chargingPlan(_ request: ChargingPlanRequest) async -> Result<ChargingPlanResponse, APIError> {
        chargingPlanCallCount += 1
        lastChargingPlanRequest = request
        return mockChargingPlanResponse ?? .failure(.invalidResponse)
    }

    func geocode(address: String) async -> Result<GeocodeResponse, APIError> {
        geocodeCallCount += 1
        return mockGeocodeResponse
    }

    func reverseGeocode(latitude: Double, longitude: Double) async -> Result<ReverseGeocodeResponse, APIError> {
        reverseGeocodeCallCount += 1
        lastReverseGeocodeArgs = (latitude, longitude)
        // Default to a benign empty response so tests that don't
        // care about reverse geocoding don't crash. Tests that
        // need a specific response set `mockReverseGeocodeResponse`.
        return mockReverseGeocodeResponse ?? .success(ReverseGeocodeResponse(
            latitude: latitude, longitude: longitude,
            address: nil, formattedAddress: nil
        ))
    }

    func getTeslaAuthUrl() async -> Result<TeslaAuthUrlResponse, APIError> {
        teslaAuthUrlCallCount += 1
        return mockTeslaAuthUrlResponse
    }

    func checkTeslaStatus(userId: String) async -> Result<TeslaStatusResponse, APIError> {
        teslaStatusCallCount += 1
        return mockTeslaStatusResponse
    }

    func unbindTesla(userId: String) async -> Result<BaseResponse, APIError> {
        unbindTeslaCallCount += 1
        return mockUnbindTeslaResponse
    }

    func validateToken() async -> Result<AuthValidationResponse, APIError> {
        validateTokenCallCount += 1
        return mockValidateTokenResponse
    }

    func refreshToken(_ refreshToken: String) async -> Result<AuthResponse, APIError> {
        refreshTokenCallCount += 1
        return mockRefreshTokenResponse
    }

    func getVehicles(userId: String) async -> Result<VehiclesResponse, APIError> {
        getVehiclesCallCount += 1
        return mockVehiclesResponse
    }

    func getVehicleState(vehicleId: String, userId: String) async -> Result<VehicleState, APIError> {
        getVehicleStateCallCount += 1
        if !mockVehicleStateSequence.isEmpty {
            let result = mockVehicleStateSequence.first!
            if mockVehicleStateSequence.count > 1 {
                mockVehicleStateSequence.removeFirst()
            }
            return result
        }
        return mockVehicleStateResponse
    }

    func wakeVehicle(vehicleId: String, userId: String) async -> Result<WakeResponse, APIError> {
        wakeVehicleCallCount += 1
        return mockWakeVehicleResponse
    }

    func sendNavigation(vehicleId: String, request: NavigationRequest) async -> Result<BaseResponse, APIError> {
        sendNavigationCallCount += 1
        lastNavigationRequest = request
        return mockSendNavigationResponse
    }

    var mockSetClimateKeeperModeResponse: Result<BaseResponse, APIError>!
    var setClimateKeeperModeCallCount = 0
    var lastSetClimateKeeperModeArgs: (vehicleId: String, mode: Int)?

    func setClimateKeeperMode(vehicleId: String, mode: Int) async -> Result<BaseResponse, APIError> {
        setClimateKeeperModeCallCount += 1
        lastSetClimateKeeperModeArgs = (vehicleId, mode)
        return mockSetClimateKeeperModeResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    var mockSetSentryModeResponse: Result<BaseResponse, APIError>!
    var setSentryModeCallCount = 0
    var lastSetSentryModeArgs: (vehicleId: String, on: Bool)?

    func setSentryMode(vehicleId: String, on: Bool) async -> Result<BaseResponse, APIError> {
        setSentryModeCallCount += 1
        lastSetSentryModeArgs = (vehicleId, on)
        return mockSetSentryModeResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    var mockPreheatResponse: Result<BaseResponse, APIError>!
    var preheatCallCount = 0
    var lastPreheatVehicleId: String?

    func preheat(vehicleId: String) async -> Result<BaseResponse, APIError> {
        preheatCallCount += 1
        lastPreheatVehicleId = vehicleId
        return mockPreheatResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    var mockLockVehicleResponse: Result<BaseResponse, APIError>!
    var lockVehicleCallCount = 0
    var lastLockVehicleId: String?

    func lockVehicle(vehicleId: String) async -> Result<BaseResponse, APIError> {
        lockVehicleCallCount += 1
        lastLockVehicleId = vehicleId
        return mockLockVehicleResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    var mockUnlockVehicleResponse: Result<BaseResponse, APIError>!
    var unlockVehicleCallCount = 0
    var lastUnlockVehicleId: String?

    func unlockVehicle(vehicleId: String) async -> Result<BaseResponse, APIError> {
        unlockVehicleCallCount += 1
        lastUnlockVehicleId = vehicleId
        return mockUnlockVehicleResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    var mockSetChargeLimitResponse: Result<BaseResponse, APIError>!
    var setChargeLimitCallCount = 0
    var lastSetChargeLimitArgs: (vehicleId: String, percent: Int)?

    func setChargeLimit(vehicleId: String, percent: Int) async -> Result<BaseResponse, APIError> {
        setChargeLimitCallCount += 1
        lastSetChargeLimitArgs = (vehicleId, percent)
        return mockSetChargeLimitResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    var mockInvokeCapabilityResponse: Result<BaseResponse, APIError>?
    var invokeCapabilityCallCount = 0
    /// Captures every invocation in order — multi-step actions emit
    /// multiple calls per run, so a single "last args" tuple would
    /// hide the sequence. Tests can assert the full list.
    var invokeCapabilityCalls: [(vehicleId: String, capability: String, params: [String: JSONValue])] = []
    func invokeCapability(
        vehicleId: String,
        capability: String,
        params: [String: JSONValue]
    ) async -> Result<BaseResponse, APIError> {
        invokeCapabilityCallCount += 1
        invokeCapabilityCalls.append((vehicleId, capability, params))
        return mockInvokeCapabilityResponse ?? .success(BaseResponse(success: true, message: "ok"))
    }

    var mockUserSettings: [String: JSONValue] = [:]
    var getUserSettingsCallCount = 0
    func getUserSettings() async -> Result<[String: JSONValue], APIError> {
        getUserSettingsCallCount += 1
        return .success(mockUserSettings)
    }
    var lastPutUserSettings: (settings: [String: JSONValue], replaceAll: Bool)?
    func putUserSettings(
        _ settings: [String: JSONValue],
        replaceAll: Bool
    ) async -> Result<[String: JSONValue], APIError> {
        lastPutUserSettings = (settings, replaceAll)
        // Merge into the mock store so consecutive get→put→get round-trips
        // mimic the real backend's merge-on-PUT behavior.
        if replaceAll {
            mockUserSettings = settings
        } else {
            for (k, v) in settings {
                mockUserSettings[k] = v
            }
        }
        return .success(mockUserSettings)
    }

    func getNearbyStations(latitude: Double, longitude: Double, radiusKm: Int, type: String?) async -> Result<[ChargingStation], APIError> {
        nearbyStationsCallCount += 1
        lastNearbyStationsArgs = (latitude, longitude, radiusKm, type)
        return mockNearbyStationsResponse
    }

    func getRecentRoutes(limit: Int, offset: Int) async -> Result<RecentRoutesResponse, APIError> {
        recentRoutesCallCount += 1
        lastRecentRoutesArgs = (limit, offset)
        return mockRecentRoutesResponse
    }

    var lastSaveRoutePlanRequest: SaveRoutePlanRequest?
    var mockSaveRoutePlanResponse: Result<SaveRoutePlanResponse, APIError> = .success(
        SaveRoutePlanResponse(id: 1, createdAt: "2026-05-12T00:00:00Z")
    )
    func saveRoutePlan(_ request: SaveRoutePlanRequest) async -> Result<SaveRoutePlanResponse, APIError> {
        lastSaveRoutePlanRequest = request
        return mockSaveRoutePlanResponse
    }

    func registerDeviceToken(_ token: String, bundleId: String?) async -> Result<BaseResponse, APIError> {
        return .success(BaseResponse(success: true, message: "ok"))
    }

    // MARK: - Shares
    var lastCreateShareArgs: (type: ShareType, payload: [String: JSONValue], expiresInDays: Int, minAppVersion: String?)?
    var mockCreateShareResponse: Result<ShareDetailResponse, APIError> = .failure(.invalidURL)
    func createShare(
        type: ShareType,
        payload: [String: JSONValue],
        expiresInDays: Int,
        minAppVersion: String?,
    ) async -> Result<ShareDetailResponse, APIError> {
        lastCreateShareArgs = (type, payload, expiresInDays, minAppVersion)
        return mockCreateShareResponse
    }

    var lastLookupShareCode: String?
    var mockLookupShareResponse: Result<ShareDetailResponse, APIError> = .failure(.invalidURL)
    func lookupShare(code: String) async -> Result<ShareDetailResponse, APIError> {
        lastLookupShareCode = code
        return mockLookupShareResponse
    }

    var lastRevokeShareCode: String?
    var mockRevokeShareResponse: Result<Void, APIError> = .success(())
    func revokeShare(code: String) async -> Result<Void, APIError> {
        lastRevokeShareCode = code
        return mockRevokeShareResponse
    }

    var mockListMySharesResponse: Result<ShareListResponse, APIError> = .success(ShareListResponse(shares: []))
    func listMyShares() async -> Result<ShareListResponse, APIError> {
        return mockListMySharesResponse
    }

    var mockListAutomationsResponse: Result<[RuleRecord], APIError> = .success([])
    var listAutomationsCallCount = 0
    func listAutomations() async -> Result<[RuleRecord], APIError> {
        listAutomationsCallCount += 1
        return mockListAutomationsResponse
    }

    var lastCreateAutomationArgs: (name: String, enabled: Bool, spec: RuleSpec)?
    func createAutomation(name: String, enabled: Bool, spec: RuleSpec) async -> Result<RuleRecord, APIError> {
        lastCreateAutomationArgs = (name, enabled, spec)
        return .success(RuleRecord(id: "new-id", presetId: nil, name: name, enabled: enabled, spec: spec))
    }

    var lastUpdateAutomationArgs: (id: String, name: String?, enabled: Bool?, spec: RuleSpec?)?
    func updateAutomation(id: String, name: String?, enabled: Bool?, spec: RuleSpec?) async -> Result<RuleRecord, APIError> {
        lastUpdateAutomationArgs = (id, name, enabled, spec)
        return .success(RuleRecord(id: id, presetId: nil, name: name ?? "", enabled: enabled ?? true, spec: spec ?? [:]))
    }

    var lastDeleteAutomationId: String?
    func deleteAutomation(id: String) async -> Result<BaseResponse, APIError> {
        lastDeleteAutomationId = id
        return .success(BaseResponse(success: true, message: "deleted"))
    }

    var mockListCapabilitiesResponse: Result<[CapabilityInfo], APIError> = .success([])
    func listCapabilities() async -> Result<[CapabilityInfo], APIError> {
        mockListCapabilitiesResponse
    }

    var mockFetchAutomationStateResponse: Result<TelemetryStateResponse, APIError> =
        .success(TelemetryStateResponse(vehicleId: nil, entries: []))
    func fetchAutomationState() async -> Result<TelemetryStateResponse, APIError> {
        mockFetchAutomationStateResponse
    }

    var mockPendingCommands: Result<PendingCommandListResponse, APIError> =
        .success(PendingCommandListResponse(pending: []))
    func fetchPendingCommands() async -> Result<PendingCommandListResponse, APIError> {
        mockPendingCommands
    }

    var mockQueuedCommands: Result<QueuedCommandListResponse, APIError> =
        .success(QueuedCommandListResponse(queued: []))
    func fetchQueuedCommands() async -> Result<QueuedCommandListResponse, APIError> {
        mockQueuedCommands
    }

    var lastCancelQueuedId: Int?
    func cancelQueuedCommand(id: Int) async -> Result<BaseResponse, APIError> {
        lastCancelQueuedId = id
        return .success(BaseResponse(success: true, message: "cancelled"))
    }

    var mockRecentFires: Result<RecentFiresResponse, APIError> =
        .success(RecentFiresResponse(fires: []))
    func fetchRecentFires(limit: Int) async -> Result<RecentFiresResponse, APIError> {
        mockRecentFires
    }

    // Phase D.1 — snoozes. Defaults to "always succeeds, return what
    // the caller asked for". Tests override via the per-call
    // `mockSnoozeResponse` to inject failures or fixed deadlines.
    var mockSnoozeResponse: Result<SnoozeRecord, APIError>?
    var mockUnsnoozeResponse: Result<BaseResponse, APIError> =
        .success(BaseResponse(success: true, message: "ok"))
    var mockSnoozeListResponse: Result<SnoozeListResponse, APIError> =
        .success(SnoozeListResponse(snoozes: []))

    private(set) var snoozeCalls: [(ruleId: String, hours: Double?, until: Date?, reason: String?)] = []
    private(set) var unsnoozeCalls: [String] = []
    private(set) var fetchSnoozesCallCount: Int = 0

    func snoozeRule(
        ruleId: String, hours: Double?, until: Date?, reason: String?
    ) async -> Result<SnoozeRecord, APIError> {
        snoozeCalls.append((ruleId, hours, until, reason))
        if let preset = mockSnoozeResponse { return preset }
        let computedUntil = until ?? Date().addingTimeInterval((hours ?? 1) * 3600)
        let record = SnoozeRecord(
            ruleId: ruleId,
            snoozedUntilUtc: computedUntil,
            reason: reason,
            createdAt: Date(),
        )
        return .success(record)
    }

    func unsnoozeRule(ruleId: String) async -> Result<BaseResponse, APIError> {
        unsnoozeCalls.append(ruleId)
        return mockUnsnoozeResponse
    }

    func fetchSnoozes() async -> Result<SnoozeListResponse, APIError> {
        fetchSnoozesCallCount += 1
        return mockSnoozeListResponse
    }

    // Phase D.2 — rule order
    var mockReorderResponse: Result<[RuleRecord], APIError>?
    private(set) var reorderCalls: [(ruleIds: [String], clear: Bool)] = []
    func reorderAutomations(
        ruleIds: [String], clear: Bool
    ) async -> Result<[RuleRecord], APIError> {
        reorderCalls.append((ruleIds, clear))
        return mockReorderResponse ?? .success([])
    }

    // Phase D.3 — scheduled departure
    var mockScheduledDepartureResponse: Result<ScheduledDepartureResponse?, APIError> =
        .success(nil)
    var mockUpsertScheduledDepartureResponse: Result<ScheduledDepartureResponse, APIError>?
    var mockClearScheduledDepartureResponse: Result<BaseResponse, APIError> =
        .success(BaseResponse(success: true, message: "ok"))
    private(set) var upsertScheduledDepartureCalls: [ScheduledDeparture] = []
    private(set) var clearScheduledDepartureCallCount: Int = 0
    private(set) var fetchScheduledDepartureCallCount: Int = 0

    func fetchScheduledDeparture() async -> Result<ScheduledDepartureResponse?, APIError> {
        fetchScheduledDepartureCallCount += 1
        return mockScheduledDepartureResponse
    }

    func upsertScheduledDeparture(
        _ departure: ScheduledDeparture
    ) async -> Result<ScheduledDepartureResponse, APIError> {
        upsertScheduledDepartureCalls.append(departure)
        if let preset = mockUpsertScheduledDepartureResponse { return preset }
        let resp = ScheduledDepartureResponse(
            id: 1,
            departureAtUtc: departure.departureAt,
            leadMinutes: departure.leadTimeMinutes,
            label: departure.label,
            vehicleId: departure.vehicleId,
            targetChargeSoc: nil,
            enabled: true,
            fireAtUtc: departure.fireAt,
            createdAt: Date(),
            updatedAt: Date(),
        )
        return .success(resp)
    }

    func clearScheduledDeparture() async -> Result<BaseResponse, APIError> {
        clearScheduledDepartureCallCount += 1
        return mockClearScheduledDepartureResponse
    }

    // Phase D.4 — charging sessions
    var mockUpsertChargingSessionResponse: Result<ChargingSessionResponse, APIError>?
    var mockListChargingSessionsResponse: Result<ChargingSessionListResponse, APIError> =
        .success(ChargingSessionListResponse(sessions: []))
    private(set) var upsertChargingSessionCalls: [(vehicleId: String, request: ChargingSessionRequest)] = []
    private(set) var listChargingSessionsCalls: [(vehicleId: String, limit: Int)] = []

    func upsertChargingSession(
        vehicleId: String, request: ChargingSessionRequest
    ) async -> Result<ChargingSessionResponse, APIError> {
        upsertChargingSessionCalls.append((vehicleId, request))
        if let preset = mockUpsertChargingSessionResponse { return preset }
        let resp = ChargingSessionResponse(
            id: 1,
            vehicleId: vehicleId,
            clientSessionId: request.clientSessionId,
            startedAt: request.startedAt,
            endedAt: request.endedAt,
            startSoc: request.startSoc,
            endSoc: request.endSoc,
            startRangeKm: request.startRangeKm,
            endRangeKm: request.endRangeKm,
            energyAddedKwh: request.energyAddedKwh,
            locationName: request.locationName,
            lat: request.lat,
            lng: request.lng,
            endedAsComplete: request.endedAsComplete,
            source: "ios",
            durationMinutes: nil,
            rangeAddedKm: nil,
            socDelta: nil,
        )
        return .success(resp)
    }

    func listChargingSessions(
        vehicleId: String, limit: Int
    ) async -> Result<ChargingSessionListResponse, APIError> {
        listChargingSessionsCalls.append((vehicleId, limit))
        return mockListChargingSessionsResponse
    }

    // Phase D.5 — charge-limit suggestion
    var mockSuggestChargeLimitResponse: Result<SuggestChargeLimitResponse, APIError>?
    private(set) var suggestChargeLimitCalls: [(vehicleId: String, request: SuggestChargeLimitRequest)] = []
    func suggestChargeLimit(
        vehicleId: String, request: SuggestChargeLimitRequest
    ) async -> Result<SuggestChargeLimitResponse, APIError> {
        suggestChargeLimitCalls.append((vehicleId, request))
        if let preset = mockSuggestChargeLimitResponse { return preset }
        return .success(SuggestChargeLimitResponse(
            recommendedPercent: request.dailyLimitSoc,
            currentPercent: request.currentLimit,
            reason: "daily",
            hoursAway: nil,
            alreadyMatches: request.currentLimit == request.dailyLimitSoc,
        ))
    }
}
