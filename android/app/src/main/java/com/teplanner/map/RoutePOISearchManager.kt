package com.teplanner.map

import android.content.Context
import com.amap.api.services.core.AMapException
import com.amap.api.services.core.LatLonPoint
import com.amap.api.services.routepoisearch.RoutePOIItem
import com.amap.api.services.routepoisearch.RoutePOISearch
import com.amap.api.services.routepoisearch.RoutePOISearchQuery
import com.amap.api.services.routepoisearch.RoutePOISearchResult
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manager for searching POIs along a route
 *
 * Note: RoutePOISearch only supports these types:
 * - TypeGasStation (加油站)
 * - TypeATM
 * - TypeMaintenanceStation (汽修店)
 * - TypeToilet (厕所)
 *
 * For charging stations, use PoiSearchManager with keyword "充电站" instead.
 */
@Singleton
class RoutePOISearchManager @Inject constructor(
    private val context: Context
) : RoutePOISearch.OnRoutePOISearchListener {

    private var onResultCallback: ((List<RoutePOIItem>) -> Unit)? = null
    private var onErrorCallback: ((Int, String) -> Unit)? = null

    /**
     * Search gas stations along a route
     * @param polyline List of points representing the route (max 100 points recommended)
     * @param range Search range in meters from the road (default 250m)
     * @param onResult Callback with list of gas stations found
     * @param onError Optional error callback
     */
    fun searchGasStationsAlongRoute(
        polyline: List<LatLonPoint>,
        range: Int = 250,
        onResult: (List<RoutePOIItem>) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        searchAlongRoute(
            polyline = polyline,
            searchType = RoutePOISearch.RoutePOISearchType.TypeGasStation,
            range = range,
            onResult = onResult,
            onError = onError
        )
    }

    /**
     * Search service areas (maintenance stations) along a route
     */
    fun searchServiceAreasAlongRoute(
        polyline: List<LatLonPoint>,
        range: Int = 250,
        onResult: (List<RoutePOIItem>) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        searchAlongRoute(
            polyline = polyline,
            searchType = RoutePOISearch.RoutePOISearchType.TypeMaintenanceStation,
            range = range,
            onResult = onResult,
            onError = onError
        )
    }

    /**
     * Search ATMs along a route
     */
    fun searchATMsAlongRoute(
        polyline: List<LatLonPoint>,
        range: Int = 250,
        onResult: (List<RoutePOIItem>) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        searchAlongRoute(
            polyline = polyline,
            searchType = RoutePOISearch.RoutePOISearchType.TypeATM,
            range = range,
            onResult = onResult,
            onError = onError
        )
    }

    /**
     * Search toilets along a route
     */
    fun searchToiletsAlongRoute(
        polyline: List<LatLonPoint>,
        range: Int = 500,
        onResult: (List<RoutePOIItem>) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        searchAlongRoute(
            polyline = polyline,
            searchType = RoutePOISearch.RoutePOISearchType.TypeToilet,
            range = range,
            onResult = onResult,
            onError = onError
        )
    }

    /**
     * Search charging stations along a route
     * Note: TypeChargeStation is available since AMap SDK 9.3.1
     */
    fun searchChargingStationsAlongRoute(
        polyline: List<LatLonPoint>,
        range: Int = 5000,
        onResult: (List<RoutePOIItem>) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        android.util.Log.d("RoutePOISearchManager", "searchChargingStationsAlongRoute: polyline size=${polyline.size}, range=$range")
        searchAlongRoute(
            polyline = polyline,
            searchType = RoutePOISearch.RoutePOISearchType.TypeChargeStation,
            range = range,
            onResult = onResult,
            onError = onError
        )
    }

    /**
     * Generic search along route
     * Note: polyline should not exceed 100 points for best results
     */
    private fun searchAlongRoute(
        polyline: List<LatLonPoint>,
        searchType: RoutePOISearch.RoutePOISearchType,
        range: Int,
        onResult: (List<RoutePOIItem>) -> Unit,
        onError: ((Int, String) -> Unit)?
    ) {
        if (polyline.size < 2) {
            onResult(emptyList())
            return
        }

        onResultCallback = onResult
        onErrorCallback = onError

        // Use the polyline-based constructor
        val query = RoutePOISearchQuery(polyline, searchType, range)

        val search = RoutePOISearch(context, query)
        search.setPoiSearchListener(this)
        search.searchRoutePOIAsyn()
    }

    override fun onRoutePoiSearched(result: RoutePOISearchResult?, errorCode: Int) {
        android.util.Log.d("RoutePOISearchManager", "onRoutePoiSearched: errorCode=$errorCode")
        when (errorCode) {
            AMapException.CODE_AMAP_SUCCESS -> {
                val pois = result?.routePois ?: emptyList()
                android.util.Log.d("RoutePOISearchManager", "Found ${pois.size} POIs along route")
                pois.forEachIndexed { index, poi ->
                    android.util.Log.d("RoutePOISearchManager", "POI[$index]: ${poi.title}, lat=${poi.point?.latitude}, lng=${poi.point?.longitude}, distance=${poi.distance}m")
                }
                onResultCallback?.invoke(pois)
            }
            else -> {
                val errorMsg = getErrorMessage(errorCode)
                android.util.Log.e("RoutePOISearchManager", "Search error: $errorCode - $errorMsg")
                onErrorCallback?.invoke(errorCode, errorMsg)
                onResultCallback?.invoke(emptyList())
            }
        }
    }

    private fun getErrorMessage(errorCode: Int): String {
        return "Error code: $errorCode"
    }
}
