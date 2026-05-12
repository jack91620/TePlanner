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

    /// Persist a planned trip to the user's 最近 history after the
    /// destination is pushed to the car. Backend at POST /routes/save.
    /// Without this call the 最近 tab is permanently empty — iOS
    /// shipped the equivalent in commit 60b5162; mirror that here.
    @POST("api/v1/routes/save")
    suspend fun saveRoutePlan(@Body request: SaveRoutePlanRequest): SaveRoutePlanResponse

    /// User's recent saved trips. Backend returns newest-first up to
    /// `limit` (default 10). Used by Map 最近 tab.
    @GET("api/v1/routes/")
    suspend fun listMyRoutePlans(
        @Query("limit") limit: Int = 10,
        @Query("offset") offset: Int = 0,
    ): RoutePlanListResponse
}
