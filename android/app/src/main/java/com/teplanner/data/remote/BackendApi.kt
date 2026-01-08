package com.teplanner.data.remote

import com.teplanner.data.model.ChargingPlanRequest
import com.teplanner.data.model.ChargingPlanResponse
import com.teplanner.data.model.ChargingStation
import com.teplanner.data.model.Vehicle
import com.teplanner.data.model.VehicleState
import com.teplanner.data.model.VehiclesResponse
import retrofit2.http.*

/**
 * Backend API interface for TePlanner server
 */
interface BackendApi {

    // ============ Authentication ============

    @POST("auth/register")
    suspend fun register(@Body request: RegisterRequest): AuthResponse

    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): AuthResponse

    @GET("auth/validate")
    suspend fun validateToken(): AuthValidationResponse

    @POST("auth/refresh")
    suspend fun refreshToken(@Body request: RefreshTokenRequest): AuthResponse

    // ============ Tesla OAuth ============

    @GET("auth/tesla/authorize")
    suspend fun getTeslaAuthUrl(): TeslaAuthUrlResponse

    @GET("auth/tesla/status")
    suspend fun checkTeslaStatus(@Query("user_id") userId: String): TeslaStatusResponse

    @POST("auth/tesla/unbind")
    suspend fun unbindTesla(@Query("user_id") userId: String): BaseResponse

    // ============ Vehicles ============

    @GET("vehicles/")
    suspend fun getVehicles(): VehiclesResponse

    @GET("vehicles/{id}/state")
    suspend fun getVehicleState(@Path("id") vehicleId: String): VehicleState

    @POST("vehicles/{id}/wake")
    suspend fun wakeVehicle(@Path("id") vehicleId: String): WakeResponse

    @POST("vehicles/{id}/navigate")
    suspend fun sendNavigation(
        @Path("id") vehicleId: String,
        @Body request: NavigationRequest
    ): BaseResponse

    // ============ Charging Plan ============

    @POST("routes/charging-plan")
    suspend fun getChargingPlan(@Body request: ChargingPlanRequest): ChargingPlanResponse

    // ============ Charging Stations ============

    @GET("charging/stations/{id}")
    suspend fun getStationDetail(@Path("id") stationId: String): ChargingStation

    @GET("charging/nearby")
    suspend fun getNearbyStations(
        @Query("latitude") latitude: Double,
        @Query("longitude") longitude: Double,
        @Query("radius") radius: Int = 50,
        @Query("type") type: String? = null
    ): List<ChargingStation>
}

// ============ Request/Response Models ============

data class LoginRequest(
    val email: String,
    val password: String
)

data class RegisterRequest(
    val email: String,
    val password: String,
    val name: String? = null
)

data class RefreshTokenRequest(
    val refresh_token: String
)

data class AuthResponse(
    val token: String,
    val refresh_token: String? = null,
    val user_id: String,
    val expires_in: Long? = null
)

data class AuthValidationResponse(
    val valid: Boolean,
    val user_id: String?,
    val has_tesla_linked: Boolean = false
)

data class TeslaAuthUrlResponse(
    val url: String,
    val state: String,
    val user_id: Int? = null
)

data class TeslaStatusResponse(
    val linked: Boolean,
    val expired: Boolean = false,
    val vehicle_count: Int = 0
)

data class WakeResponse(
    val vehicle_id: String? = null,
    val state: String? = null,
    val message: String? = null
) {
    // Derive success from state - if not offline and not unknown, consider it success
    val success: Boolean
        get() = state != null && state != "offline" && state != "unknown"
}

data class Location(
    val latitude: Double,
    val longitude: Double,
    val name: String? = null
)

data class NavigationRequest(
    val latitude: Double,
    val longitude: Double,
    val name: String? = null,
    val waypoints: List<Location>? = null
)

data class BaseResponse(
    val success: Boolean,
    val message: String? = null
)
