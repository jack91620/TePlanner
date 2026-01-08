package com.teplanner.map

import android.content.Context
import com.amap.api.services.core.AMapException
import com.amap.api.services.core.LatLonPoint
import com.amap.api.services.core.PoiItemV2
import com.amap.api.services.poisearch.PoiResultV2
import com.amap.api.services.poisearch.PoiSearchV2
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manager for POI (Point of Interest) search
 */
@Singleton
class PoiSearchManager @Inject constructor(
    private val context: Context
) : PoiSearchV2.OnPoiSearchListener {

    private var onResultCallback: ((List<PoiItemV2>) -> Unit)? = null
    private var onErrorCallback: ((Int, String) -> Unit)? = null

    /**
     * Search POIs by keyword
     * @param keyword Search keyword
     * @param city City name or adcode
     * @param poiType POI type code (e.g., "011100" for gas stations)
     * @param pageNum Page number (starting from 0)
     * @param pageSize Items per page
     * @param onResult Callback with search results
     * @param onError Optional error callback
     */
    fun searchByKeyword(
        keyword: String,
        city: String = "",
        poiType: String = "",
        pageNum: Int = 0,
        pageSize: Int = 20,
        onResult: (List<PoiItemV2>) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        onResultCallback = onResult
        onErrorCallback = onError

        val query = PoiSearchV2.Query(keyword, poiType, city)
        query.pageSize = pageSize
        query.pageNum = pageNum

        val poiSearch = PoiSearchV2(context, query)
        poiSearch.setOnPoiSearchListener(this)
        poiSearch.searchPOIAsyn()
    }

    /**
     * Search POIs around a location
     * @param keyword Search keyword
     * @param center Center point for search
     * @param radius Search radius in meters
     * @param poiType POI type code
     * @param onResult Callback with search results
     * @param onError Optional error callback
     */
    fun searchAround(
        keyword: String,
        center: LatLonPoint,
        radius: Int = 3000,
        poiType: String = "",
        pageNum: Int = 0,
        pageSize: Int = 20,
        onResult: (List<PoiItemV2>) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        onResultCallback = onResult
        onErrorCallback = onError

        val query = PoiSearchV2.Query(keyword, poiType)
        query.pageSize = pageSize
        query.pageNum = pageNum

        val poiSearch = PoiSearchV2(context, query)
        poiSearch.bound = PoiSearchV2.SearchBound(center, radius)
        poiSearch.setOnPoiSearchListener(this)
        poiSearch.searchPOIAsyn()
    }

    /**
     * Search charging stations around a location
     */
    fun searchChargingStationsAround(
        center: LatLonPoint,
        radius: Int = 5000,
        onResult: (List<PoiItemV2>) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        searchAround(
            keyword = "充电站",
            center = center,
            radius = radius,
            poiType = "011100", // Charging station type code
            onResult = onResult,
            onError = onError
        )
    }

    override fun onPoiSearched(result: PoiResultV2?, errorCode: Int) {
        android.util.Log.d("PoiSearchManager", "onPoiSearched: errorCode=$errorCode, result=$result")
        when (errorCode) {
            AMapException.CODE_AMAP_SUCCESS -> {
                val pois = result?.pois ?: emptyList()
                android.util.Log.d("PoiSearchManager", "Search success, found ${pois.size} POIs")
                pois.forEachIndexed { index, poi ->
                    android.util.Log.d("PoiSearchManager", "POI[$index]: title=${poi.title}, latLonPoint=${poi.latLonPoint}")
                }
                onResultCallback?.invoke(pois)
            }
            else -> {
                val errorMsg = getErrorMessage(errorCode)
                android.util.Log.e("PoiSearchManager", "Search error: $errorCode - $errorMsg")
                onErrorCallback?.invoke(errorCode, errorMsg)
                onResultCallback?.invoke(emptyList())
            }
        }
    }

    override fun onPoiItemSearched(poiItem: PoiItemV2?, errorCode: Int) {
        // Not used
    }

    private fun getErrorMessage(errorCode: Int): String {
        return "Error code: $errorCode"
    }

    fun searchPOI(
        keyword: String,
        city: String = "",
        onResult: (List<PoiItemV2>) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        searchByKeyword(keyword, city, "", 0, 20, onResult, onError)
    }
}
