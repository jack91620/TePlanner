package com.teplanner.map

import android.content.Context
import com.amap.api.services.core.AMapException
import com.amap.api.services.core.LatLonPoint
import com.amap.api.services.route.BusRouteResult
import com.amap.api.services.route.DrivePath
import com.amap.api.services.route.DriveRouteResult
import com.amap.api.services.route.RideRouteResult
import com.amap.api.services.route.RouteSearch
import com.amap.api.services.route.WalkRouteResult
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Result of a driving route search
 */
data class DrivingRouteResult(
    val paths: List<DrivePath>,
    val totalDistanceMeters: Float,
    val totalDurationSeconds: Long,
    val polyline: List<LatLonPoint>
)

/**
 * Manager for route planning using AMap SDK
 */
@Singleton
class RouteSearchManager @Inject constructor(
    private val context: Context
) : RouteSearch.OnRouteSearchListener {

    private var routeSearch: RouteSearch? = null
    private var onDrivingResultCallback: ((DrivingRouteResult?) -> Unit)? = null
    private var onErrorCallback: ((Int, String) -> Unit)? = null

    init {
        routeSearch = RouteSearch(context)
        routeSearch?.setRouteSearchListener(this)
    }

    /**
     * Search for driving route between two points
     * @param origin Starting point
     * @param destination End point
     * @param waypoints Optional intermediate waypoints
     * @param strategy Driving strategy (default: fastest)
     * @param onResult Callback with route result
     * @param onError Optional error callback
     */
    fun searchDrivingRoute(
        origin: LatLonPoint,
        destination: LatLonPoint,
        waypoints: List<LatLonPoint>? = null,
        strategy: Int = RouteSearch.DRIVING_SINGLE_DEFAULT,
        onResult: (DrivingRouteResult?) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        onDrivingResultCallback = onResult
        onErrorCallback = onError

        val fromAndTo = RouteSearch.FromAndTo(origin, destination)
        val query = RouteSearch.DriveRouteQuery(
            fromAndTo,
            strategy,
            waypoints,
            null, // avoidPolygons
            ""    // avoidRoad
        )

        routeSearch?.calculateDriveRouteAsyn(query)
    }

    /**
     * Search driving route with multiple waypoints
     */
    fun searchDrivingRouteWithWaypoints(
        origin: LatLonPoint,
        destination: LatLonPoint,
        waypoints: List<LatLonPoint>,
        onResult: (DrivingRouteResult?) -> Unit,
        onError: ((Int, String) -> Unit)? = null
    ) {
        searchDrivingRoute(
            origin = origin,
            destination = destination,
            waypoints = waypoints,
            strategy = RouteSearch.DRIVING_SINGLE_DEFAULT,
            onResult = onResult,
            onError = onError
        )
    }

    override fun onDriveRouteSearched(result: DriveRouteResult?, errorCode: Int) {
        when (errorCode) {
            AMapException.CODE_AMAP_SUCCESS -> {
                if (result?.paths?.isNotEmpty() == true) {
                    val path = result.paths[0]
                    val polyline = extractPolyline(path)

                    val routeResult = DrivingRouteResult(
                        paths = result.paths,
                        totalDistanceMeters = path.distance,
                        totalDurationSeconds = path.duration,
                        polyline = polyline
                    )
                    onDrivingResultCallback?.invoke(routeResult)
                } else {
                    onDrivingResultCallback?.invoke(null)
                }
            }
            else -> {
                val errorMsg = getErrorMessage(errorCode)
                onErrorCallback?.invoke(errorCode, errorMsg)
                onDrivingResultCallback?.invoke(null)
            }
        }
    }

    /**
     * Extract polyline points from drive path
     */
    private fun extractPolyline(path: DrivePath): List<LatLonPoint> {
        val points = mutableListOf<LatLonPoint>()
        path.steps.forEach { step ->
            points.addAll(step.polyline)
        }
        return points
    }

    override fun onBusRouteSearched(result: BusRouteResult?, errorCode: Int) {
        // Not implemented - we only use driving routes
    }

    override fun onWalkRouteSearched(result: WalkRouteResult?, errorCode: Int) {
        // Not implemented
    }

    override fun onRideRouteSearched(result: RideRouteResult?, errorCode: Int) {
        // Not implemented
    }

    private fun getErrorMessage(errorCode: Int): String {
        return "Error code: $errorCode"
    }
}
