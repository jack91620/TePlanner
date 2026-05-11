package cloud.teplanner.android.core.network

import kotlinx.serialization.Serializable
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Vehicle list/state + VCP commands. Command endpoints mirror iOS
 * APIService (apps/ios/Sources/TePlannerKit/Services/APIService.swift).
 * All command endpoints route server-side through tesla-http-proxy
 * with VCP signing.
 */
interface VehiclesApi {
    @GET("api/v1/vehicles/")
    suspend fun list(@Query("user_id") userId: String): VehiclesListResponse

    @GET("api/v1/vehicles/{id}/state")
    suspend fun state(
        @Path("id") vehicleId: String,
        @Query("user_id") userId: String,
    ): VehicleStateResponse

    // -- VCP commands. Each writes a CommandPending row server-side
    // when the capability has an expected_state, so the same converge-
    // poll banner UX works regardless of which client dispatches.

    @POST("api/v1/vehicles/{id}/sentry-mode")
    suspend fun setSentryMode(
        @Path("id") vehicleId: String,
        @Body body: SetSentryRequest,
    ): BaseResponse

    @POST("api/v1/vehicles/{id}/climate-keeper-mode")
    suspend fun setClimateKeeperMode(
        @Path("id") vehicleId: String,
        @Body body: SetClimateKeeperRequest,
    ): BaseResponse

    @POST("api/v1/vehicles/{id}/lock")
    suspend fun lockVehicle(@Path("id") vehicleId: String): BaseResponse

    @POST("api/v1/vehicles/{id}/unlock")
    suspend fun unlockVehicle(@Path("id") vehicleId: String): BaseResponse

    @POST("api/v1/vehicles/{id}/preheat")
    suspend fun preheat(@Path("id") vehicleId: String): BaseResponse

    @POST("api/v1/vehicles/{id}/charge-limit")
    suspend fun setChargeLimit(
        @Path("id") vehicleId: String,
        @Body body: SetChargeLimitRequest,
    ): BaseResponse

    @POST("api/v1/vehicles/{id}/suggest-charge-limit")
    suspend fun suggestChargeLimit(
        @Path("id") vehicleId: String,
        @Body body: SuggestChargeLimitRequest,
    ): SuggestChargeLimitResponse

    @POST("api/v1/vehicles/{id}/navigate")
    suspend fun sendNavigation(
        @Path("id") vehicleId: String,
        @Body body: NavigationRequest,
    ): BaseResponse

    // -- Command status / queue (for the converge-poll banner).

    @GET("api/v1/vehicles/commands/pending")
    suspend fun pendingCommands(): PendingCommandListResponse

    @GET("api/v1/vehicles/commands/queued")
    suspend fun queuedCommands(): QueuedCommandListResponse
}

@Serializable
data class SetSentryRequest(val on: Boolean)

@Serializable
data class SetClimateKeeperRequest(val mode: Int)

@Serializable
data class SetChargeLimitRequest(val percent: Int)

@Serializable
data class NavigationRequest(
    val latitude: Double,
    val longitude: Double,
    val name: String? = null,
)

@Serializable
data class SuggestChargeLimitRequest(
    @kotlinx.serialization.SerialName("current_limit") val currentLimit: Int? = null,
    @kotlinx.serialization.SerialName("daily_limit_soc") val dailyLimitSoc: Int = 80,
    @kotlinx.serialization.SerialName("trip_limit_soc") val tripLimitSoc: Int = 100,
    @kotlinx.serialization.SerialName("trip_window_hours") val tripWindowHours: Int = 12,
)

@Serializable
data class SuggestChargeLimitResponse(
    @kotlinx.serialization.SerialName("recommended_percent") val recommendedPercent: Int,
    @kotlinx.serialization.SerialName("current_percent") val currentPercent: Int? = null,
    val reason: String,
    @kotlinx.serialization.SerialName("hours_away") val hoursAway: Int? = null,
    @kotlinx.serialization.SerialName("already_matches") val alreadyMatches: Boolean,
)

@Serializable
data class PendingCommandListResponse(val pending: List<PendingCommandRow> = emptyList())

@Serializable
data class PendingCommandRow(
    val id: Int,
    val capability: String,
    @kotlinx.serialization.SerialName("dispatched_at") val dispatchedAt: String,
    @kotlinx.serialization.SerialName("confirmed_at") val confirmedAt: String? = null,
    @kotlinx.serialization.SerialName("timed_out_at") val timedOutAt: String? = null,
    val status: String,
)

@Serializable
data class QueuedCommandListResponse(val queued: List<QueuedCommandRow> = emptyList())

@Serializable
data class QueuedCommandRow(
    val id: Int,
    val capability: String,
    val status: String,
    @kotlinx.serialization.SerialName("sent_at") val sentAt: String? = null,
    @kotlinx.serialization.SerialName("dropped_at") val droppedAt: String? = null,
    val error: String? = null,
)
