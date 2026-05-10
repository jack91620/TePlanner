package cloud.teplanner.android.core.network

import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Phase F.3.2 — charging endpoints. `nearby` is unauthenticated
 * (read-only POI proxy); `stations/{id}` is too. Auth interceptor
 * still attaches the token if present, harmless for these routes.
 */
interface ChargingApi {

    @GET("api/v1/charging/nearby")
    suspend fun nearby(
        @Query("latitude") latitude: Double,
        @Query("longitude") longitude: Double,
        @Query("type") type: String = "all",
        @Query("radius") radiusKm: Double = 50.0,
    ): StationSearchResponse

    @GET("api/v1/charging/stations/{id}")
    suspend fun station(@Path("id") id: String): ChargingStation
}
