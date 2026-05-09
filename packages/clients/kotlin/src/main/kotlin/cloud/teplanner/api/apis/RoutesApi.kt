package cloud.teplanner.api.apis

import cloud.teplanner.api.infrastructure.CollectionFormats.*
import retrofit2.http.*
import retrofit2.Response
import okhttp3.RequestBody
import com.squareup.moshi.Json

import cloud.teplanner.api.models.ChargingPlanRequest
import cloud.teplanner.api.models.ChargingPlanResponse
import cloud.teplanner.api.models.GeocodeRequest
import cloud.teplanner.api.models.GeocodeResponse
import cloud.teplanner.api.models.HTTPValidationError
import cloud.teplanner.api.models.NavigateRouteRequest
import cloud.teplanner.api.models.RouteOnlyRequest
import cloud.teplanner.api.models.RouteOnlyResponse
import cloud.teplanner.api.models.RoutePlanResponse

interface RoutesApi {
    /**
     * POST api/v1/routes/charging-plan
     * Charging Plan
     * Phase 8.2: greedy charging-stop selection over client-provided candidate POIs. Pure computation — no map API call.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param chargingPlanRequest 
     * @return [ChargingPlanResponse]
     */
    @POST("api/v1/routes/charging-plan")
    suspend fun chargingPlanApiV1RoutesChargingPlanPost(@Body chargingPlanRequest: ChargingPlanRequest): Response<ChargingPlanResponse>

    /**
     * POST api/v1/routes/geocode
     * Geocode Address
     * Convert address to coordinates.  Useful for getting coordinates from user-entered addresses.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param geocodeRequest 
     * @return [GeocodeResponse]
     */
    @POST("api/v1/routes/geocode")
    suspend fun geocodeAddressApiV1RoutesGeocodePost(@Body geocodeRequest: GeocodeRequest): Response<GeocodeResponse>

    /**
     * GET api/v1/routes/saved/{route_id}
     * Get Route
     * Get a saved route plan.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param routeId 
     * @return [RoutePlanResponse]
     */
    @GET("api/v1/routes/saved/{route_id}")
    suspend fun getRouteApiV1RoutesSavedRouteIdGet(@Path("route_id") routeId: kotlin.Int): Response<RoutePlanResponse>

    /**
     * GET api/v1/routes/
     * List Routes
     * List user&#39;s saved routes.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param limit  (optional, default to 10)
     * @param offset  (optional, default to 0)
     * @return [kotlin.Any]
     */
    @GET("api/v1/routes/")
    suspend fun listRoutesApiV1RoutesGet(@Query("limit") limit: kotlin.Int? = 10, @Query("offset") offset: kotlin.Int? = 0): Response<kotlin.Any>

    /**
     * POST api/v1/routes/navigate
     * Navigate Route
     * Send planned route to vehicle.  Sends navigation waypoints to the vehicle&#39;s navigation system. By default, sends the charging stops as waypoints.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param navigateRouteRequest 
     * @return [kotlin.Any]
     */
    @POST("api/v1/routes/navigate")
    suspend fun navigateRouteApiV1RoutesNavigatePost(@Body navigateRouteRequest: NavigateRouteRequest): Response<kotlin.Any>

    /**
     * POST api/v1/routes/navigate/{route_id}
     * Navigate Saved Route
     * Send a saved route&#39;s charging stops + destination to the user&#39;s primary Tesla vehicle. Logic lives in &#x60;services/route_dispatch_service.send_saved_route_to_vehicle&#x60;.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param routeId 
     * @return [kotlin.Any]
     */
    @POST("api/v1/routes/navigate/{route_id}")
    suspend fun navigateSavedRouteApiV1RoutesNavigateRouteIdPost(@Path("route_id") routeId: kotlin.Int): Response<kotlin.Any>

    /**
     * POST api/v1/routes/reverse-geocode
     * Reverse Geocode
     * Convert coordinates to address.  Useful for displaying readable location names.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param latitude 
     * @param longitude 
     * @return [kotlin.Any]
     */
    @POST("api/v1/routes/reverse-geocode")
    suspend fun reverseGeocodeApiV1RoutesReverseGeocodePost(@Query("latitude") latitude: java.math.BigDecimal, @Query("longitude") longitude: java.math.BigDecimal): Response<kotlin.Any>

    /**
     * POST api/v1/routes/route
     * Route Only
     * Phase 8.2: AMap routing only — polyline + distance + duration.  No POI search, no charging plan. iOS calls this first, then runs AMap SDK along-route POI search locally, then POSTs candidate POIs back to /routes/charging-plan to compute the greedy stops.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param routeOnlyRequest 
     * @return [RouteOnlyResponse]
     */
    @POST("api/v1/routes/route")
    suspend fun routeOnlyApiV1RoutesRoutePost(@Body routeOnlyRequest: RouteOnlyRequest): Response<RouteOnlyResponse>

    /**
     * GET api/v1/routes/search
     * Search Places
     * Search for places by keyword.  Args:     keyword: Search keyword (e.g., city name, POI name)     location: Optional center location \&quot;lat,lng\&quot; for distance calculation  Returns:     List of matching places with name, address, location and distance
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param keyword 
     * @param location  (optional)
     * @return [kotlin.Any]
     */
    @GET("api/v1/routes/search")
    suspend fun searchPlacesApiV1RoutesSearchGet(@Query("keyword") keyword: kotlin.String, @Query("location") location: kotlin.String? = null): Response<kotlin.Any>

}
