package cloud.teplanner.api.apis

import cloud.teplanner.api.infrastructure.CollectionFormats.*
import retrofit2.http.*
import retrofit2.Response
import okhttp3.RequestBody
import com.squareup.moshi.Json

import cloud.teplanner.api.models.ChargingStation
import cloud.teplanner.api.models.HTTPValidationError
import cloud.teplanner.api.models.StationSearchResponse

interface ChargingApi {
    /**
     * GET api/v1/charging/stations/{station_id}
     * Get Station
     * 获取充电站详情.  Args:     station_id: 充电站ID
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param stationId 
     * @return [ChargingStation]
     */
    @GET("api/v1/charging/stations/{station_id}")
    suspend fun getStationApiV1ChargingStationsStationIdGet(@Path("station_id") stationId: kotlin.String): Response<ChargingStation>

    /**
     * GET api/v1/charging/nearby
     * Search Nearby Stations
     * 搜索附近充电站 (前端兼容接口).  Args:     latitude: 中心点纬度     longitude: 中心点经度     type: 充电站类型     radius: 搜索半径，默认50公里
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param latitude 中心点纬度
     * @param longitude 中心点经度
     * @param type 类型: supercharger/destination/service/all (optional)
     * @param radius 搜索半径(公里) (optional, default to 50)
     * @return [StationSearchResponse]
     */
    @GET("api/v1/charging/nearby")
    suspend fun searchNearbyStationsApiV1ChargingNearbyGet(@Query("latitude") latitude: java.math.BigDecimal, @Query("longitude") longitude: java.math.BigDecimal, @Query("type") type: kotlin.String? = null, @Query("radius") radius: java.math.BigDecimal? = java.math.BigDecimal("50")): Response<StationSearchResponse>

    /**
     * GET api/v1/charging/stations
     * Search Stations
     * 搜索附近充电站.  Args:     lat: 中心点纬度     lng: 中心点经度     radius_km: 搜索半径，默认10公里     min_power_kw: 最小充电功率筛选     operator: 运营商筛选
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param lat 中心点纬度
     * @param lng 中心点经度
     * @param radiusKm 搜索半径(公里) (optional, default to 10)
     * @param minPowerKw 最小充电功率(kW) (optional)
     * @param `operator` 运营商筛选 (optional)
     * @return [StationSearchResponse]
     */
    @GET("api/v1/charging/stations")
    suspend fun searchStationsApiV1ChargingStationsGet(@Query("lat") lat: java.math.BigDecimal, @Query("lng") lng: java.math.BigDecimal, @Query("radius_km") radiusKm: java.math.BigDecimal? = java.math.BigDecimal("10"), @Query("min_power_kw") minPowerKw: kotlin.Int? = null, @Query("operator") `operator`: kotlin.String? = null): Response<StationSearchResponse>

}
