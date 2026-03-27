package com.teplanner.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.LatLngBounds
import com.amap.api.maps.model.Marker
import com.amap.api.maps.model.MarkerOptions
import com.amap.api.maps.model.PolylineOptions
import com.amap.api.services.core.LatLonPoint
import com.teplanner.R
import com.teplanner.data.local.SettingsDataStore
import com.teplanner.data.model.ChargingStation
import com.teplanner.data.remote.BackendApi
import com.teplanner.map.AMapManager
import com.teplanner.map.RouteSearchManager
import com.teplanner.map.RoutePOISearchManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HomeUiState(
    val isLoading: Boolean = true,
    val pageState: HomePageState = HomePageState.IDLE,
    val vehicleConnected: Boolean = false,
    val batteryLevel: Int? = null,
    val batteryRangeKm: Double? = null, // Remaining range in km
    val vehicleDisplayState: VehicleDisplayState? = null,
    val vehicleLocation: LatLng? = null,
    val error: String? = null,
    val isWakingVehicle: Boolean = false,
    // New state for nearby stations and recent trips
    val nearbyStations: List<ChargingStation> = emptyList(),
    val isLoadingStations: Boolean = false,
    val recentTrips: List<RecentTrip> = emptyList(),
    val departureSOC: Int = 80,
    val routeData: RouteData? = null,
    val destination: Destination? = null
)

data class Destination(
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val address: String?
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val backendApi: BackendApi,
    private val settingsDataStore: SettingsDataStore,
    private val aMapManager: AMapManager,
    private val routeSearchManager: RouteSearchManager,
    private val routePOISearchManager: RoutePOISearchManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    private var aMap: AMap? = null
    private var currentVehicleId: String? = null
    private val currentUserId: String = "15" // Fixed user_id for now
    private var vehicleMarker: Marker? = null
    private var routePolylinePoints: List<LatLonPoint> = emptyList()

    init {
        checkAuthAndLoadData()
    }

    fun onMapReady(map: AMap) {
        aMap = map
        // If we have vehicle location, move camera there and add marker
        _uiState.value.vehicleLocation?.let { location ->
            map.moveCamera(CameraUpdateFactory.newLatLngZoom(location, 14f))
            updateVehicleMarker(location)
        }
        // Load nearby stations when map is ready
        loadNearbyStations()
    }

    private fun updateVehicleMarker(location: LatLng) {
        val map = aMap ?: return

        // Remove existing marker if any
        vehicleMarker?.remove()

        // Add new marker at vehicle location
        val markerOptions = MarkerOptions()
            .position(location)
            .title(_uiState.value.vehicleDisplayState?.displayName ?: "My Tesla")
            .snippet("电量: ${_uiState.value.batteryLevel ?: 0}%")
            .anchor(0.5f, 0.5f)
            .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE))

        vehicleMarker = map.addMarker(markerOptions)
        android.util.Log.d("HomeViewModel", "Vehicle marker added at: ${location.latitude}, ${location.longitude}")
    }

    private fun checkAuthAndLoadData() {
        viewModelScope.launch {
            // Check if Tesla is linked
            val isTeslaLinked = settingsDataStore.teslaLinked.first()
            android.util.Log.d("HomeViewModel", "checkAuthAndLoadData: isTeslaLinked = $isTeslaLinked")

            if (isTeslaLinked) {
                loadVehicleData()
            } else {
                _uiState.update { it.copy(isLoading = false, vehicleConnected = false) }
            }
        }
    }

    private fun loadVehicleData() {
        viewModelScope.launch {
            try {
                android.util.Log.d("HomeViewModel", "Using fixed user_id: $currentUserId")

                // Check Tesla status
                val teslaStatus = backendApi.checkTeslaStatus(currentUserId)
                if (!teslaStatus.linked) {
                    _uiState.update { it.copy(isLoading = false, vehicleConnected = false) }
                    return@launch
                }

                // Get vehicles
                val vehiclesResponse = backendApi.getVehicles(currentUserId)
                if (vehiclesResponse.vehicles.isEmpty()) {
                    _uiState.update { it.copy(isLoading = false, vehicleConnected = false) }
                    return@launch
                }

                val vehicle = vehiclesResponse.vehicles.first()
                currentVehicleId = vehicle.id

                // Try to get vehicle state, wake if needed
                fetchVehicleStateWithWake(vehicle.id, vehicle.displayName ?: "My Tesla")

            } catch (e: Exception) {
                _uiState.update {
                    it.copy(isLoading = false, error = e.message)
                }
            }
        }
    }

    private suspend fun fetchVehicleStateWithWake(vehicleId: String, displayName: String) {
        // First attempt to get state
        try {
            val state = backendApi.getVehicleState(vehicleId, currentUserId)
            updateVehicleState(state, displayName)
            return
        } catch (e: Exception) {
            android.util.Log.d("HomeViewModel", "Initial state fetch failed: ${e.message}, trying to wake vehicle")
        }

        // Vehicle is likely asleep, try to wake it
        _uiState.update {
            it.copy(
                isLoading = false,
                isWakingVehicle = true,
                vehicleConnected = true,
                vehicleDisplayState = VehicleDisplayState(
                    displayName = displayName,
                    stateText = "唤醒中...",
                    batteryLevel = 0,
                    rangeKm = 0
                )
            )
        }

        try {
            android.util.Log.d("HomeViewModel", "Sending wake command to vehicle: $vehicleId")
            val wakeResponse = backendApi.wakeVehicle(vehicleId, currentUserId)
            android.util.Log.d("HomeViewModel", "Wake response: success=${wakeResponse.success}, state=${wakeResponse.state}")

            // Wait and retry getting state multiple times
            val maxRetries = 10
            val retryDelayMs = 3000L

            for (attempt in 1..maxRetries) {
                android.util.Log.d("HomeViewModel", "Retry attempt $attempt/$maxRetries to get vehicle state")
                delay(retryDelayMs)

                try {
                    val state = backendApi.getVehicleState(vehicleId, currentUserId)
                    android.util.Log.d("HomeViewModel", "Got vehicle state on attempt $attempt: battery=${state.batteryLevel}, lat=${state.latitude}, lng=${state.longitude}")
                    _uiState.update { it.copy(isWakingVehicle = false) }
                    updateVehicleState(state, displayName)
                    return
                } catch (retryException: Exception) {
                    android.util.Log.d("HomeViewModel", "Attempt $attempt failed: ${retryException.message}")
                    // Update status text
                    _uiState.update {
                        it.copy(
                            vehicleDisplayState = VehicleDisplayState(
                                displayName = displayName,
                                stateText = "唤醒中... ($attempt/$maxRetries)",
                                batteryLevel = 0,
                                rangeKm = 0
                            )
                        )
                    }
                }
            }

            // All retries failed
            android.util.Log.d("HomeViewModel", "Failed to wake vehicle after $maxRetries attempts")
            _uiState.update {
                it.copy(
                    isWakingVehicle = false,
                    vehicleDisplayState = VehicleDisplayState(
                        displayName = displayName,
                        stateText = "离线",
                        batteryLevel = 0,
                        rangeKm = 0
                    )
                )
            }
        } catch (wakeException: Exception) {
            android.util.Log.e("HomeViewModel", "Failed to wake vehicle: ${wakeException.message}")
            _uiState.update {
                it.copy(
                    isWakingVehicle = false,
                    vehicleDisplayState = VehicleDisplayState(
                        displayName = displayName,
                        stateText = "离线",
                        batteryLevel = 0,
                        rangeKm = 0
                    )
                )
            }
        }
    }

    private fun updateVehicleState(state: com.teplanner.data.model.VehicleState, displayName: String) {
        val location = if (state.latitude != null && state.longitude != null) {
            LatLng(state.latitude, state.longitude)
        } else null

        _uiState.update {
            it.copy(
                isLoading = false,
                vehicleConnected = true,
                batteryLevel = state.batteryLevel,
                batteryRangeKm = state.batteryRange,
                vehicleLocation = location,
                departureSOC = state.batteryLevel ?: 80,
                vehicleDisplayState = VehicleDisplayState(
                    displayName = displayName,
                    stateText = getStateText("online", state.chargingState),
                    batteryLevel = state.batteryLevel ?: 0,
                    rangeKm = state.batteryRange?.toInt() ?: 0
                )
            )
        }

        // Move map to vehicle location and add marker
        location?.let { loc ->
            aMap?.moveCamera(CameraUpdateFactory.newLatLngZoom(loc, 14f))
            updateVehicleMarker(loc)
        }

        // Load nearby stations based on vehicle location
        loadNearbyStations()

        // Load recent trips
        loadRecentTrips()
    }

    private fun loadNearbyStations() {
        val location = _uiState.value.vehicleLocation ?: return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingStations = true) }
            try {
                val stations = backendApi.getNearbyStations(
                    latitude = location.latitude,
                    longitude = location.longitude,
                    radius = 50,
                    type = "supercharger"
                )
                _uiState.update {
                    it.copy(
                        nearbyStations = stations,
                        isLoadingStations = false
                    )
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoadingStations = false) }
            }
        }
    }

    private fun loadRecentTrips() {
        // In a real app, this would load from local storage
        // For now, using empty list
        _uiState.update { it.copy(recentTrips = emptyList()) }
    }

    fun centerOnVehicle() {
        _uiState.value.vehicleLocation?.let { location ->
            aMap?.animateCamera(CameraUpdateFactory.newLatLngZoom(location, 16f))
        } ?: run {
            // Try to get current location
            aMapManager.getCurrentLocation { amapLocation ->
                amapLocation?.let {
                    val location = LatLng(it.latitude, it.longitude)
                    aMap?.animateCamera(CameraUpdateFactory.newLatLngZoom(location, 16f))
                }
            }
        }
    }

    fun refreshVehicleState() {
        loadVehicleData()
    }

    fun navigateToStation(station: ChargingStation) {
        _uiState.update {
            it.copy(
                destination = Destination(
                    name = station.name,
                    latitude = station.latitude,
                    longitude = station.longitude,
                    address = station.address
                )
            )
        }
        planRoute()
    }

    fun setDestination(name: String, latitude: Double, longitude: Double, address: String?) {
        android.util.Log.d("HomeViewModel", "setDestination: name=$name, lat=$latitude, lng=$longitude")
        _uiState.update {
            it.copy(
                destination = Destination(
                    name = name,
                    latitude = latitude,
                    longitude = longitude,
                    address = address
                )
            )
        }
        planRoute()
    }

    fun navigateToTrip(trip: RecentTrip) {
        _uiState.update {
            it.copy(
                destination = Destination(
                    name = trip.destinationName,
                    latitude = trip.latitude,
                    longitude = trip.longitude,
                    address = trip.destinationAddress
                )
            )
        }
        planRoute()
    }

    private var routeSearchRetryCount = 0
    private val maxRouteSearchRetries = 3

    private fun planRoute() {
        val destination = _uiState.value.destination ?: return
        val origin = _uiState.value.vehicleLocation ?: return

        android.util.Log.d("HomeViewModel", "planRoute: from (${origin.latitude}, ${origin.longitude}) to (${destination.latitude}, ${destination.longitude})")

        _uiState.update { it.copy(pageState = HomePageState.ROUTE_PREVIEW) }
        routeSearchRetryCount = 0

        performRouteSearch(origin, destination)
    }

    private fun performRouteSearch(origin: LatLng, destination: Destination) {
        // Convert to LatLonPoint for AMap SDK
        val originPoint = LatLonPoint(origin.latitude, origin.longitude)
        val destPoint = LatLonPoint(destination.latitude, destination.longitude)

        android.util.Log.d("HomeViewModel", "performRouteSearch: attempt ${routeSearchRetryCount + 1}/$maxRouteSearchRetries")

        // Search driving route
        routeSearchManager.searchDrivingRoute(
            origin = originPoint,
            destination = destPoint,
            onResult = { routeResult ->
                if (routeResult != null) {
                    android.util.Log.d("HomeViewModel", "Route found: ${routeResult.totalDistanceMeters}m, ${routeResult.totalDurationSeconds}s, polyline points: ${routeResult.polyline.size}")

                    // Store polyline for later use
                    routePolylinePoints = routeResult.polyline

                    // Draw route on map
                    drawRouteOnMap(routeResult.polyline, origin, destination)

                    // Calculate distance and duration
                    val distanceKm = routeResult.totalDistanceMeters / 1000.0
                    val durationMinutes = (routeResult.totalDurationSeconds / 60).toInt()
                    val durationStr = if (durationMinutes >= 60) {
                        "${durationMinutes / 60}小时${durationMinutes % 60}分钟"
                    } else {
                        "${durationMinutes}分钟"
                    }

                    // Search charging stations along route
                    searchChargingStationsAlongRoute(routeResult.polyline, distanceKm, durationStr, destination.name)
                } else {
                    android.util.Log.e("HomeViewModel", "Route search returned null")
                    _uiState.update {
                        it.copy(
                            routeData = RouteData(
                                destinationName = destination.name,
                                totalDistanceKm = 0.0,
                                totalDuration = "路线规划失败",
                                arrivalSoc = 0,
                                chargingStops = emptyList()
                            )
                        )
                    }
                }
            },
            onError = { errorCode, errorMsg ->
                android.util.Log.e("HomeViewModel", "Route search error: $errorCode - $errorMsg, attempt ${routeSearchRetryCount + 1}/$maxRouteSearchRetries")
                routeSearchRetryCount++

                if (routeSearchRetryCount < maxRouteSearchRetries) {
                    // Retry after delay
                    viewModelScope.launch {
                        android.util.Log.d("HomeViewModel", "Retrying route search in 2 seconds...")
                        delay(2000L)
                        performRouteSearch(origin, destination)
                    }
                } else {
                    // All retries exhausted, show failure
                    android.util.Log.e("HomeViewModel", "Route search failed after $maxRouteSearchRetries attempts")
                    _uiState.update {
                        it.copy(
                            routeData = RouteData(
                                destinationName = destination.name,
                                totalDistanceKm = 0.0,
                                totalDuration = "路线规划失败 (网络错误)",
                                arrivalSoc = 0,
                                chargingStops = emptyList()
                            )
                        )
                    }
                }
            }
        )
    }

    private fun drawRouteOnMap(polyline: List<LatLonPoint>, origin: LatLng, destination: Destination) {
        val map = aMap ?: return

        // Clear previous route
        map.clear()

        // Re-add vehicle marker
        updateVehicleMarker(origin)

        // Convert polyline to LatLng list
        val latLngList = polyline.map { LatLng(it.latitude, it.longitude) }

        // Draw polyline
        val polylineOptions = PolylineOptions()
            .addAll(latLngList)
            .width(12f)
            .color(0xFF3E6AE1.toInt()) // Blue color
            .geodesic(true)

        map.addPolyline(polylineOptions)

        // Add destination marker
        val destMarkerOptions = MarkerOptions()
            .position(LatLng(destination.latitude, destination.longitude))
            .title(destination.name)
            .anchor(0.5f, 1f)
            .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_RED))

        map.addMarker(destMarkerOptions)

        // Adjust camera to show entire route
        val boundsBuilder = LatLngBounds.Builder()
        boundsBuilder.include(origin)
        boundsBuilder.include(LatLng(destination.latitude, destination.longitude))
        latLngList.forEach { boundsBuilder.include(it) }

        try {
            map.animateCamera(CameraUpdateFactory.newLatLngBounds(boundsBuilder.build(), 100))
        } catch (e: Exception) {
            android.util.Log.e("HomeViewModel", "Failed to adjust camera: ${e.message}")
        }
    }

    private fun searchChargingStationsAlongRoute(polyline: List<LatLonPoint>, distanceKm: Double, durationStr: String, destinationName: String) {
        android.util.Log.d("HomeViewModel", "Searching charging stations along route, polyline size: ${polyline.size}, totalDistance: ${distanceKm}km")

        // For long routes (>300km), search in segments to get better coverage
        val segmentDistanceKm = 250.0 // Search every 250km segment
        val numSegments = ((distanceKm / segmentDistanceKm).toInt() + 1).coerceAtMost(10)

        android.util.Log.d("HomeViewModel", "Route will be searched in $numSegments segments")

        val allStations = mutableListOf<com.amap.api.services.routepoisearch.RoutePOIItem>()
        var completedSegments = 0

        // Function to process results after all segments complete
        fun processAllResults() {
            android.util.Log.d("HomeViewModel", "All segments complete. Total stations found: ${allStations.size}")

            // Remove duplicates by ID or location
            val uniqueStations = allStations.distinctBy { it.id ?: "${it.point?.latitude},${it.point?.longitude}" }
            android.util.Log.d("HomeViewModel", "Unique stations after dedup: ${uniqueStations.size}")

            val currentSoc = _uiState.value.departureSOC
            val origin = _uiState.value.vehicleLocation

            // Calculate distance along route for each station
            val stationsWithDistance = if (origin != null) {
                uniqueStations.mapNotNull { station ->
                    station.point?.let { point ->
                        val distanceFromStart = estimateDistanceAlongRoute(
                            polyline,
                            LatLonPoint(origin.latitude, origin.longitude),
                            point,
                            distanceKm
                        )
                        android.util.Log.d("HomeViewModel", "Station ${station.title}: distanceFromStart=${String.format("%.1f", distanceFromStart)}km")
                        Pair(station, distanceFromStart)
                    }
                }.sortedBy { it.second }
            } else {
                emptyList()
            }

            val chargingStops = calculateChargingStops(stationsWithDistance, distanceKm, currentSoc)

            // Only add markers for recommended charging stops
            addRecommendedChargingStationMarkers(chargingStops, stationsWithDistance)

            // Calculate arrival SOC
            val arrivalSoc = calculateArrivalSoc(distanceKm, currentSoc, chargingStops)

            _uiState.update {
                it.copy(
                    routeData = RouteData(
                        destinationName = destinationName,
                        totalDistanceKm = distanceKm,
                        totalDuration = durationStr,
                        arrivalSoc = arrivalSoc,
                        chargingStops = chargingStops
                    )
                )
            }
        }

        // Search each segment
        for (segmentIndex in 0 until numSegments) {
            val startRatio = segmentIndex.toDouble() / numSegments
            val endRatio = ((segmentIndex + 1).toDouble() / numSegments).coerceAtMost(1.0)

            val startIdx = (polyline.size * startRatio).toInt()
            val endIdx = (polyline.size * endRatio).toInt().coerceAtMost(polyline.size - 1)

            // Get segment polyline
            val segmentPolyline = polyline.subList(startIdx, endIdx + 1)

            // Simplify if needed
            val simplifiedSegment = if (segmentPolyline.size > 50) {
                val step = segmentPolyline.size / 50
                segmentPolyline.filterIndexed { index, _ -> index % step == 0 }
            } else {
                segmentPolyline
            }

            android.util.Log.d("HomeViewModel", "Searching segment $segmentIndex: points ${startIdx}-${endIdx}, simplified to ${simplifiedSegment.size} points")

            routePOISearchManager.searchChargingStationsAlongRoute(
                polyline = simplifiedSegment,
                range = 10000, // 10km from route for better coverage
                onResult = { stations ->
                    android.util.Log.d("HomeViewModel", "Segment $segmentIndex found ${stations.size} stations")
                    synchronized(allStations) {
                        allStations.addAll(stations)
                        completedSegments++
                        if (completedSegments >= numSegments) {
                            processAllResults()
                        }
                    }
                },
                onError = { errorCode, errorMsg ->
                    android.util.Log.e("HomeViewModel", "Segment $segmentIndex search error: $errorCode - $errorMsg")
                    synchronized(allStations) {
                        completedSegments++
                        if (completedSegments >= numSegments) {
                            processAllResults()
                        }
                    }
                }
            )
        }
    }

    /**
     * Estimate distance along route from origin to a station point
     */
    private fun estimateDistanceAlongRoute(
        polyline: List<LatLonPoint>,
        origin: LatLonPoint,
        stationPoint: LatLonPoint,
        totalDistanceKm: Double
    ): Double {
        if (polyline.isEmpty()) return 0.0

        // Find the closest point on polyline to the station
        var minDistance = Double.MAX_VALUE
        var closestIndex = 0

        polyline.forEachIndexed { index, point ->
            val dist = haversineDistance(point.latitude, point.longitude, stationPoint.latitude, stationPoint.longitude)
            if (dist < minDistance) {
                minDistance = dist
                closestIndex = index
            }
        }

        // Estimate distance along route based on polyline index proportion
        return (closestIndex.toDouble() / polyline.size) * totalDistanceKm
    }

    /**
     * Calculate distance between two points using Haversine formula
     */
    private fun haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val R = 6371.0 // Earth's radius in km
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                Math.sin(dLon / 2) * Math.sin(dLon / 2)
        val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return R * c
    }

    private fun addRecommendedChargingStationMarkers(
        recommendedStops: List<ChargingStopData>,
        allStations: List<Pair<com.amap.api.services.routepoisearch.RoutePOIItem, Double>>
    ) {
        val map = aMap ?: return

        // Only add markers for recommended stops
        recommendedStops.forEach { stop ->
            val station = allStations.find { it.first.id == stop.stationId || it.first.title == stop.name }
            station?.first?.point?.let { point ->
                val markerOptions = MarkerOptions()
                    .position(LatLng(point.latitude, point.longitude))
                    .title(stop.name)
                    .snippet("到达 ${stop.arrivalSoc}% | 充电 ${stop.chargingDuration}分钟")
                    .anchor(0.5f, 1f)
                    .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_RED))

                map.addMarker(markerOptions)
            }
        }
    }

    /**
     * Calculate energy consumption rate based on actual vehicle data
     * @return km per 1% SOC
     */
    private fun getEnergyConsumptionRate(): Double {
        val batteryLevel = _uiState.value.batteryLevel
        val batteryRangeKm = _uiState.value.batteryRangeKm

        return if (batteryLevel != null && batteryRangeKm != null && batteryLevel > 0) {
            // Calculate based on actual vehicle data: rangeKm / batteryLevel = km per 1% SOC
            val rate = batteryRangeKm / batteryLevel
            android.util.Log.d("HomeViewModel", "Energy rate from vehicle: ${batteryLevel}% = ${batteryRangeKm}km, rate = ${rate}km/1%SOC")
            rate
        } else {
            // Fallback: Tesla Model 3 Long Range default (~250km at 100%)
            android.util.Log.d("HomeViewModel", "Using default energy rate: 2.5km/1%SOC")
            2.5
        }
    }

    private fun calculateArrivalSoc(distanceKm: Double, startSoc: Int, chargingStops: List<ChargingStopData>): Int {
        val rangePerPercent = getEnergyConsumptionRate()

        if (chargingStops.isEmpty()) {
            // No charging stops - simple calculation
            val socUsed = (distanceKm / rangePerPercent).toInt()
            return (startSoc - socUsed).coerceIn(0, 100)
        }

        // With charging stops, use the last stop's departure SOC and remaining distance
        val lastStop = chargingStops.last()
        // Estimate remaining distance after last stop (rough: assume last stop at 80% of route)
        val remainingDistanceRatio = 0.2 // 20% of total distance after last stop
        val remainingDistance = distanceKm * remainingDistanceRatio
        val socUsedAfterLastStop = (remainingDistance / rangePerPercent).toInt()

        return (lastStop.departureSoc - socUsedAfterLastStop).coerceIn(0, 100)
    }

    private fun calculateChargingStops(
        stationsWithDistance: List<Pair<com.amap.api.services.routepoisearch.RoutePOIItem, Double>>,
        totalDistanceKm: Double,
        startSoc: Int
    ): List<ChargingStopData> {
        val rangePerPercent = getEnergyConsumptionRate() // km per 1% SOC
        val minSoc = 15 // Don't go below 15%
        val targetSoc = 80 // Charge to 80% for faster charging
        val safetyBuffer = 0.98 // Use 98% of calculated range - charge when close to minSoc

        android.util.Log.d("HomeViewModel", "calculateChargingStops: totalDistance=${totalDistanceKm}km, startSoc=$startSoc%, rangePerPercent=${rangePerPercent}km/%, maxRange=${startSoc * rangePerPercent}km")

        // Check if we can reach destination without charging
        val initialSafeRange = (startSoc - minSoc) * rangePerPercent * safetyBuffer
        if (totalDistanceKm <= initialSafeRange) {
            android.util.Log.d("HomeViewModel", "Can reach destination without charging (need ${totalDistanceKm}km, have ${initialSafeRange}km safe range)")
            return emptyList()
        }

        val stops = mutableListOf<ChargingStopData>()
        var currentSoc = startSoc
        var currentPosition = 0.0 // Current position along the route (km from start)

        // Greedy algorithm: always pick the farthest reachable station
        while (stops.size < 5) {
            // Calculate how far we can travel from current position
            val safeRangeKm = (currentSoc - minSoc) * rangePerPercent * safetyBuffer
            val maxReachableDistance = currentPosition + safeRangeKm

            android.util.Log.d("HomeViewModel", "From position ${currentPosition.toInt()}km with $currentSoc% SOC, can reach up to ${maxReachableDistance.toInt()}km")

            // Check if we can reach the destination
            if (maxReachableDistance >= totalDistanceKm) {
                val arrivalSoc = currentSoc - ((totalDistanceKm - currentPosition) / rangePerPercent).toInt()
                android.util.Log.d("HomeViewModel", "Can reach destination! Arrival SOC: $arrivalSoc%")
                break
            }

            // Find all stations within our reachable range
            val reachableStations = stationsWithDistance.filter { (_, dist) ->
                dist > currentPosition + 50 && // At least 50km ahead (avoid clustering)
                dist <= maxReachableDistance && // Within our range
                dist < totalDistanceKm - 50 // Not too close to destination
            }

            if (reachableStations.isEmpty()) {
                // No station in range - try to find the nearest station beyond our range
                val nearestBeyondRange = stationsWithDistance
                    .filter { (_, dist) -> dist > maxReachableDistance && dist < totalDistanceKm - 50 }
                    .minByOrNull { it.second }

                if (nearestBeyondRange != null) {
                    android.util.Log.w("HomeViewModel", "Warning: No station in safe range. Nearest is at ${nearestBeyondRange.second.toInt()}km, need to push to reach it")
                    // We'll have to risk going further than safe range
                    val (station, distanceFromStart) = nearestBeyondRange
                    val distanceTraveled = distanceFromStart - currentPosition
                    val socUsed = (distanceTraveled / rangePerPercent).toInt()
                    val arrivalSoc = (currentSoc - socUsed).coerceAtLeast(5) // Will arrive with low battery

                    val chargingMinutes = ((targetSoc - arrivalSoc) * 0.5).toInt().coerceAtLeast(15)
                    stops.add(ChargingStopData(
                        stationId = station.id ?: "",
                        name = station.title ?: "Charging Station",
                        arrivalSoc = arrivalSoc,
                        departureSoc = targetSoc,
                        chargingDuration = chargingMinutes
                    ))
                    android.util.Log.d("HomeViewModel", "Added emergency stop: ${station.title} at ${distanceFromStart.toInt()}km, arrival=$arrivalSoc%, departure=$targetSoc%")

                    currentSoc = targetSoc
                    currentPosition = distanceFromStart
                } else {
                    android.util.Log.e("HomeViewModel", "Cannot find any charging station to complete route!")
                    break
                }
            } else {
                // Pick the farthest reachable station (greedy approach)
                val (station, distanceFromStart) = reachableStations.maxByOrNull { it.second }!!

                // Calculate arrival SOC at this station
                val distanceTraveled = distanceFromStart - currentPosition
                val socUsed = (distanceTraveled / rangePerPercent).toInt()
                val arrivalSoc = (currentSoc - socUsed).coerceAtLeast(0)

                // Calculate charging time
                val chargingMinutes = ((targetSoc - arrivalSoc) * 0.5).toInt().coerceAtLeast(15)

                stops.add(ChargingStopData(
                    stationId = station.id ?: "",
                    name = station.title ?: "Charging Station",
                    arrivalSoc = arrivalSoc,
                    departureSoc = targetSoc,
                    chargingDuration = chargingMinutes
                ))

                android.util.Log.d("HomeViewModel", "Added stop: ${station.title} at ${distanceFromStart.toInt()}km, arrival=$arrivalSoc%, departure=$targetSoc%, charging=${chargingMinutes}min")

                currentSoc = targetSoc
                currentPosition = distanceFromStart
            }
        }

        android.util.Log.d("HomeViewModel", "Total charging stops: ${stops.size}")
        return stops
    }

    fun cancelRoute() {
        _uiState.update {
            it.copy(
                pageState = HomePageState.IDLE,
                destination = null,
                routeData = null
            )
        }
        // Clear route polyline from map
        aMap?.clear()
        // Reload nearby stations
        loadNearbyStations()
    }

    fun startNavigation() {
        val destination = _uiState.value.destination ?: return
        // Open in external map app
        // TODO: Implement external map navigation
    }

    fun editRoute() {
        // TODO: Navigate to route edit screen
    }

    fun editDepartureSOC() {
        // TODO: Show SOC picker dialog
    }

    fun sendToVehicle() {
        val vehicleId = currentVehicleId ?: return
        val destination = _uiState.value.destination ?: return

        viewModelScope.launch {
            try {
                backendApi.sendNavigation(
                    vehicleId = vehicleId,
                    request = com.teplanner.data.remote.NavigationRequest(
                        latitude = destination.latitude,
                        longitude = destination.longitude,
                        name = destination.name
                    )
                )
                // Show success message
            } catch (e: Exception) {
                // Show error message
            }
        }
    }

    private fun getStateText(vehicleState: String, chargingState: String?): String {
        return when {
            chargingState == "Charging" -> "充电中"
            chargingState == "Complete" -> "充电完成"
            vehicleState == "online" -> "在线"
            vehicleState == "asleep" -> "休眠"
            else -> "离线"
        }
    }
}
