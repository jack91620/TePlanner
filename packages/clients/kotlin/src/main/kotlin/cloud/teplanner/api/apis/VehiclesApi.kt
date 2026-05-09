package cloud.teplanner.api.apis

import cloud.teplanner.api.infrastructure.CollectionFormats.*
import retrofit2.http.*
import retrofit2.Response
import okhttp3.RequestBody
import com.squareup.moshi.Json

import cloud.teplanner.api.models.ChargeLimitRequest
import cloud.teplanner.api.models.ChargingSessionListResponse
import cloud.teplanner.api.models.ChargingSessionRequest
import cloud.teplanner.api.models.ChargingSessionResponse
import cloud.teplanner.api.models.ClimateKeeperModeRequest
import cloud.teplanner.api.models.HTTPValidationError
import cloud.teplanner.api.models.NavigationAddressRequest
import cloud.teplanner.api.models.NavigationRequest
import cloud.teplanner.api.models.PendingCommandListResponse
import cloud.teplanner.api.models.QueuedCommandListResponse
import cloud.teplanner.api.models.SentryModeRequest
import cloud.teplanner.api.models.SuggestChargeLimitRequest
import cloud.teplanner.api.models.SuggestChargeLimitResponse
import cloud.teplanner.api.models.VehicleListResponse
import cloud.teplanner.api.models.VehicleResponse
import cloud.teplanner.api.models.VehicleStateResponse
import cloud.teplanner.api.models.WakeResponse

interface VehiclesApi {
    /**
     * DELETE api/v1/vehicles/commands/queued/{queued_id}
     * Cancel Queued Command
     * Cancel a still-queued command before it drains. 404 if the user doesn&#39;t own it; 409 if it&#39;s already been sent/dropped.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param queuedId 
     * @return [kotlin.Any]
     */
    @DELETE("api/v1/vehicles/commands/queued/{queued_id}")
    suspend fun cancelQueuedCommandApiV1VehiclesCommandsQueuedQueuedIdDelete(@Path("queued_id") queuedId: kotlin.Int): Response<kotlin.Any>

    /**
     * GET api/v1/vehicles/{vehicle_id}
     * Get Vehicle
     * Get specific vehicle details.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @return [VehicleResponse]
     */
    @GET("api/v1/vehicles/{vehicle_id}")
    suspend fun getVehicleApiV1VehiclesVehicleIdGet(@Path("vehicle_id") vehicleId: kotlin.String): Response<VehicleResponse>

    /**
     * GET api/v1/vehicles/{vehicle_id}/state
     * Get Vehicle State
     * Get vehicle state (battery, location, etc.).  Returns real-time vehicle data including: - Battery level and range - Current location (GPS) - Charging state - Climate status
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @return [VehicleStateResponse]
     */
    @GET("api/v1/vehicles/{vehicle_id}/state")
    suspend fun getVehicleStateApiV1VehiclesVehicleIdStateGet(@Path("vehicle_id") vehicleId: kotlin.String): Response<VehicleStateResponse>

    /**
     * GET api/v1/vehicles/{vehicle_id}/sessions
     * List Charging Sessions
     * Most-recent-first session list. Default limit 50 covers ~6 weeks of typical daily-charging owners; clients pass &#x60;?limit&#x3D;N&#x60; to dig further. Strict per-user filter so a vehicle_id collision (Tesla sometimes recycles ids across accounts) can&#39;t leak rows.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @param limit  (optional, default to 50)
     * @return [ChargingSessionListResponse]
     */
    @GET("api/v1/vehicles/{vehicle_id}/sessions")
    suspend fun listChargingSessionsApiV1VehiclesVehicleIdSessionsGet(@Path("vehicle_id") vehicleId: kotlin.String, @Query("limit") limit: kotlin.Int? = 50): Response<ChargingSessionListResponse>

    /**
     * GET api/v1/vehicles/commands/pending
     * List Pending Commands
     * Phase 9 — what VCP commands sent in the last few minutes are still awaiting telemetry confirmation, plus the most recently resolved ones for the iOS UI to flip to \&quot;已关闭\&quot; / \&quot;超时\&quot;.  The resolver runs server-side on every Telemetry frame, so a well-timed poll right after dispatch will see the row transition pending → confirmed within ~1-2 s of the actual state change.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param limit  (optional, default to 20)
     * @return [PendingCommandListResponse]
     */
    @GET("api/v1/vehicles/commands/pending")
    suspend fun listPendingCommandsApiV1VehiclesCommandsPendingGet(@Query("limit") limit: kotlin.Int? = 20): Response<PendingCommandListResponse>

    /**
     * GET api/v1/vehicles/commands/queued
     * List Queued Commands
     * Return commands waiting on the car&#39;s next CONNECTED telemetry event, plus recently-resolved ones for the iOS UI to flip badges.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param limit  (optional, default to 20)
     * @return [QueuedCommandListResponse]
     */
    @GET("api/v1/vehicles/commands/queued")
    suspend fun listQueuedCommandsApiV1VehiclesCommandsQueuedGet(@Query("limit") limit: kotlin.Int? = 20): Response<QueuedCommandListResponse>

    /**
     * GET api/v1/vehicles/
     * List Vehicles
     * List user&#39;s Tesla vehicles, syncing the local Vehicle table. Logic in services/vehicle_sync_service.sync_vehicles.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [VehicleListResponse]
     */
    @GET("api/v1/vehicles/")
    suspend fun listVehiclesApiV1VehiclesGet(): Response<VehicleListResponse>

    /**
     * POST api/v1/vehicles/{vehicle_id}/navigate/address
     * Navigate Vehicle Address
     * Send navigation destination by address to vehicle.  Sends address string to the vehicle&#39;s navigation system. Vehicle must be online.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @param navigationAddressRequest 
     * @return [kotlin.Any]
     */
    @POST("api/v1/vehicles/{vehicle_id}/navigate/address")
    suspend fun navigateVehicleAddressApiV1VehiclesVehicleIdNavigateAddressPost(@Path("vehicle_id") vehicleId: kotlin.String, @Body navigationAddressRequest: NavigationAddressRequest): Response<kotlin.Any>

    /**
     * POST api/v1/vehicles/{vehicle_id}/navigate
     * Navigate Vehicle
     * Send GPS coordinates to vehicle nav. Dispatches through capability registry. Uses numeric vehicle_id (not VIN) since navigation_gps_request is one of the few endpoints not on the VCP-signed path.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @param navigationRequest 
     * @return [kotlin.Any]
     */
    @POST("api/v1/vehicles/{vehicle_id}/navigate")
    suspend fun navigateVehicleApiV1VehiclesVehicleIdNavigatePost(@Path("vehicle_id") vehicleId: kotlin.String, @Body navigationRequest: NavigationRequest): Response<kotlin.Any>

    /**
     * POST api/v1/vehicles/{vehicle_id}/preheat
     * Preheat Vehicle
     * Start HVAC (auto_conditioning_start) so the cabin is at temperature on arrival. Used by 出发前预热. Dispatches through capability registry.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @return [kotlin.Any]
     */
    @POST("api/v1/vehicles/{vehicle_id}/preheat")
    suspend fun preheatVehicleApiV1VehiclesVehicleIdPreheatPost(@Path("vehicle_id") vehicleId: kotlin.String): Response<kotlin.Any>

    /**
     * POST api/v1/vehicles/{vehicle_id}/charge-limit
     * Set Charge Limit
     * Set the vehicle&#39;s charge limit SOC percent (50..100). Dispatches through capability registry.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @param chargeLimitRequest 
     * @return [kotlin.Any]
     */
    @POST("api/v1/vehicles/{vehicle_id}/charge-limit")
    suspend fun setChargeLimitApiV1VehiclesVehicleIdChargeLimitPost(@Path("vehicle_id") vehicleId: kotlin.String, @Body chargeLimitRequest: ChargeLimitRequest): Response<kotlin.Any>

    /**
     * POST api/v1/vehicles/{vehicle_id}/climate-keeper-mode
     * Set Climate Keeper Mode
     * Set climate keeper mode. 0&#x3D;off / 1&#x3D;keep / 2&#x3D;dog / 3&#x3D;camp. Dispatches through capability registry.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @param climateKeeperModeRequest 
     * @return [kotlin.Any]
     */
    @POST("api/v1/vehicles/{vehicle_id}/climate-keeper-mode")
    suspend fun setClimateKeeperModeApiV1VehiclesVehicleIdClimateKeeperModePost(@Path("vehicle_id") vehicleId: kotlin.String, @Body climateKeeperModeRequest: ClimateKeeperModeRequest): Response<kotlin.Any>

    /**
     * POST api/v1/vehicles/{vehicle_id}/set-primary
     * Set Primary Vehicle
     * Set vehicle as primary for the user.  Only one vehicle can be primary at a time.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @return [kotlin.Any]
     */
    @POST("api/v1/vehicles/{vehicle_id}/set-primary")
    suspend fun setPrimaryVehicleApiV1VehiclesVehicleIdSetPrimaryPost(@Path("vehicle_id") vehicleId: kotlin.String): Response<kotlin.Any>

    /**
     * POST api/v1/vehicles/{vehicle_id}/sentry-mode
     * Set Sentry Mode
     * Toggle sentry mode. Dispatches through capability registry.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @param sentryModeRequest 
     * @return [kotlin.Any]
     */
    @POST("api/v1/vehicles/{vehicle_id}/sentry-mode")
    suspend fun setSentryModeApiV1VehiclesVehicleIdSentryModePost(@Path("vehicle_id") vehicleId: kotlin.String, @Body sentryModeRequest: SentryModeRequest): Response<kotlin.Any>

    /**
     * POST api/v1/vehicles/{vehicle_id}/suggest-charge-limit
     * Suggest Charge Limit Endpoint
     * Server-side mirror of iOS ChargeLimitSuggester. Reads the user&#39;s currently-stored ScheduledDeparture (A.3) to find any upcoming trip; daily/trip preferences come from the request body (Phase D will read them from /user/settings instead).
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @param suggestChargeLimitRequest 
     * @return [SuggestChargeLimitResponse]
     */
    @POST("api/v1/vehicles/{vehicle_id}/suggest-charge-limit")
    suspend fun suggestChargeLimitEndpointApiV1VehiclesVehicleIdSuggestChargeLimitPost(@Path("vehicle_id") vehicleId: kotlin.String, @Body suggestChargeLimitRequest: SuggestChargeLimitRequest): Response<SuggestChargeLimitResponse>

    /**
     * POST api/v1/vehicles/{vehicle_id}/sessions
     * Upsert Charging Session
     * Create or update a charging session.  iOS POSTs once on plug-in (ended_at NULL) and again on plug-out (ended_at set). Server upserts on &#x60;&#x60;client_session_id&#x60;&#x60; so retries are safe; if absent (legacy iOS builds), every POST creates a new row — acceptable trade-off but fix client-side first.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @param chargingSessionRequest 
     * @return [ChargingSessionResponse]
     */
    @POST("api/v1/vehicles/{vehicle_id}/sessions")
    suspend fun upsertChargingSessionApiV1VehiclesVehicleIdSessionsPost(@Path("vehicle_id") vehicleId: kotlin.String, @Body chargingSessionRequest: ChargingSessionRequest): Response<ChargingSessionResponse>

    /**
     * POST api/v1/vehicles/{vehicle_id}/wake
     * Wake Vehicle
     * Wake up the vehicle.  Sends wake-up command and waits for vehicle to come online. May take 10-30 seconds.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param vehicleId 
     * @return [WakeResponse]
     */
    @POST("api/v1/vehicles/{vehicle_id}/wake")
    suspend fun wakeVehicleApiV1VehiclesVehicleIdWakePost(@Path("vehicle_id") vehicleId: kotlin.String): Response<WakeResponse>

}
