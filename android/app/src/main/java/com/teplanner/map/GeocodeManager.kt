package com.teplanner.map

import android.content.Context
import com.amap.api.services.core.AMapException
import com.amap.api.services.core.LatLonPoint
import com.amap.api.services.geocoder.GeocodeAddress
import com.amap.api.services.geocoder.GeocodeQuery
import com.amap.api.services.geocoder.GeocodeResult
import com.amap.api.services.geocoder.GeocodeSearch
import com.amap.api.services.geocoder.RegeocodeAddress
import com.amap.api.services.geocoder.RegeocodeQuery
import com.amap.api.services.geocoder.RegeocodeResult
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manager for geocoding and reverse geocoding
 */
@Singleton
class GeocodeManager @Inject constructor(
    private val context: Context
) : GeocodeSearch.OnGeocodeSearchListener {

    private var geocodeSearch: GeocodeSearch? = null
    private var onGeocodeResultCallback: ((GeocodeAddress?) -> Unit)? = null
    private var onRegeocodeResultCallback: ((RegeocodeAddress?) -> Unit)? = null
    private var onErrorCallback: ((Int, String) -> Unit)? = null

    init {
        geocodeSearch = GeocodeSearch(context)
        geocodeSearch?.setOnGeocodeSearchListener(this)
    }

    /**
     * Convert address to coordinates (Geocode)
     * @param address Address string to convert
     * @param city City name for more accurate results
     * @param onResult Callback with geocode result
     * @param onError Optional error callback
     */
    fun geocode(
        address: String,
        city: String = "",
        onResult: (GeocodeAddress?) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        onGeocodeResultCallback = onResult
        onErrorCallback = onError

        val query = GeocodeQuery(address, city)
        geocodeSearch?.getFromLocationNameAsyn(query)
    }

    /**
     * Convert coordinates to address (Reverse Geocode)
     * @param point Location point to convert
     * @param radius Search radius in meters
     * @param onResult Callback with address result
     * @param onError Optional error callback
     */
    fun reverseGeocode(
        point: LatLonPoint,
        radius: Float = 200f,
        onResult: (RegeocodeAddress?) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        onRegeocodeResultCallback = onResult
        onErrorCallback = onError

        val query = RegeocodeQuery(point, radius, GeocodeSearch.AMAP)
        geocodeSearch?.getFromLocationAsyn(query)
    }

    override fun onGeocodeSearched(result: GeocodeResult?, errorCode: Int) {
        when (errorCode) {
            AMapException.CODE_AMAP_SUCCESS -> {
                val address = result?.geocodeAddressList?.firstOrNull()
                onGeocodeResultCallback?.invoke(address)
            }
            else -> {
                val errorMsg = getErrorMessage(errorCode)
                onErrorCallback?.invoke(errorCode, errorMsg)
                onGeocodeResultCallback?.invoke(null)
            }
        }
    }

    override fun onRegeocodeSearched(result: RegeocodeResult?, errorCode: Int) {
        when (errorCode) {
            AMapException.CODE_AMAP_SUCCESS -> {
                onRegeocodeResultCallback?.invoke(result?.regeocodeAddress)
            }
            else -> {
                val errorMsg = getErrorMessage(errorCode)
                onErrorCallback?.invoke(errorCode, errorMsg)
                onRegeocodeResultCallback?.invoke(null)
            }
        }
    }

    private fun getErrorMessage(errorCode: Int): String {
        return "Error code: $errorCode"
    }
}
