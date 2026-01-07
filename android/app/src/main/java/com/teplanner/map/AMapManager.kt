package com.teplanner.map

import android.content.Context
import com.amap.api.location.AMapLocation
import com.amap.api.location.AMapLocationClient
import com.amap.api.location.AMapLocationClientOption
import com.amap.api.location.AMapLocationListener
import com.amap.api.services.core.LatLonPoint
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manager for AMap initialization and location services
 */
@Singleton
class AMapManager @Inject constructor(
    private val context: Context
) : AMapLocationListener {

    private var locationClient: AMapLocationClient? = null
    private var onLocationCallback: ((AMapLocation?) -> Unit)? = null
    private var lastLocation: AMapLocation? = null

    /**
     * Initialize location client
     */
    fun initLocationClient() {
        if (locationClient == null) {
            locationClient = AMapLocationClient(context)
            locationClient?.setLocationListener(this)

            val option = AMapLocationClientOption().apply {
                // High accuracy mode
                locationMode = AMapLocationClientOption.AMapLocationMode.Hight_Accuracy
                // Single location (not continuous)
                isOnceLocation = true
                // Return address info
                isNeedAddress = true
                // Timeout
                httpTimeOut = 20000
            }
            locationClient?.setLocationOption(option)
        }
    }

    /**
     * Start continuous location updates
     */
    fun startContinuousLocation(
        intervalMs: Long = 5000,
        onLocation: (AMapLocation?) -> Unit
    ) {
        initLocationClient()
        onLocationCallback = onLocation

        val option = AMapLocationClientOption().apply {
            locationMode = AMapLocationClientOption.AMapLocationMode.Hight_Accuracy
            isOnceLocation = false
            this.interval = intervalMs
            isNeedAddress = true
        }
        locationClient?.setLocationOption(option)
        locationClient?.startLocation()
    }

    /**
     * Get current location once
     */
    fun getCurrentLocation(onLocation: (AMapLocation?) -> Unit) {
        initLocationClient()
        onLocationCallback = onLocation

        val option = AMapLocationClientOption().apply {
            locationMode = AMapLocationClientOption.AMapLocationMode.Hight_Accuracy
            isOnceLocation = true
            isNeedAddress = true
            httpTimeOut = 20000
        }
        locationClient?.setLocationOption(option)
        locationClient?.startLocation()
    }

    /**
     * Stop location updates
     */
    fun stopLocation() {
        locationClient?.stopLocation()
    }

    /**
     * Destroy location client
     */
    fun destroyLocationClient() {
        locationClient?.stopLocation()
        locationClient?.onDestroy()
        locationClient = null
    }

    /**
     * Get last known location
     */
    fun getLastLocation(): AMapLocation? = lastLocation

    /**
     * Get last location as LatLonPoint
     */
    fun getLastLocationPoint(): LatLonPoint? {
        return lastLocation?.let {
            LatLonPoint(it.latitude, it.longitude)
        }
    }

    override fun onLocationChanged(location: AMapLocation?) {
        if (location != null && location.errorCode == 0) {
            lastLocation = location
            onLocationCallback?.invoke(location)
        } else {
            onLocationCallback?.invoke(null)
        }
    }
}
