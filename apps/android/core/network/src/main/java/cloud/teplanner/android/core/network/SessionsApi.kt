package cloud.teplanner.android.core.network

import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

interface SessionsApi {
    @GET("api/v1/vehicles/{vehicleId}/sessions")
    suspend fun list(
        @Path("vehicleId") vehicleId: String,
        @Query("limit") limit: Int = 100,
    ): ChargingSessionListResponse
}
