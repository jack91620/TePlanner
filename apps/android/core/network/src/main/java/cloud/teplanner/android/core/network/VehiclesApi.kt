package cloud.teplanner.android.core.network

import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Phase F.2 — vehicle list + state. Tesla command endpoints
 * (charge-limit, sentry, preheat, navigate) ship with F.3
 * once the Hub UI has rule action buttons.
 */
interface VehiclesApi {
    @GET("api/v1/vehicles/")
    suspend fun list(@Query("user_id") userId: String): VehiclesListResponse

    @GET("api/v1/vehicles/{id}/state")
    suspend fun state(
        @Path("id") vehicleId: String,
        @Query("user_id") userId: String,
    ): VehicleStateResponse
}
