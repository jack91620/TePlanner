package cloud.teplanner.android.core.network

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Query

interface RoutesApi {

    @POST("api/v1/routes/route")
    suspend fun route(@Body request: RouteOnlyRequest): RouteOnlyResponse

    @POST("api/v1/routes/charging-plan")
    suspend fun chargingPlan(@Body request: ChargingPlanRequest): ChargingPlanResponse

    @GET("api/v1/routes/search")
    suspend fun searchPlaces(
        @Query("keyword") keyword: String,
        @Query("location") location: String? = null,
    ): PlaceSearchResponse
}
