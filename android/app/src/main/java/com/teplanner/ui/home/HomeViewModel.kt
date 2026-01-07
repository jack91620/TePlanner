package com.teplanner.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.model.LatLng
import com.teplanner.data.local.SettingsDataStore
import com.teplanner.data.model.ChargingStation
import com.teplanner.data.remote.BackendApi
import com.teplanner.map.AMapManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HomeUiState(
    val isLoading: Boolean = true,
    val pageState: HomePageState = HomePageState.IDLE,
    val vehicleConnected: Boolean = false,
    val batteryLevel: Int? = null,
    val vehicleDisplayState: VehicleDisplayState? = null,
    val vehicleLocation: LatLng? = null,
    val error: String? = null,
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
    private val aMapManager: AMapManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    private var aMap: AMap? = null
    private var currentVehicleId: String? = null

    init {
        checkAuthAndLoadData()
    }

    fun onMapReady(map: AMap) {
        aMap = map
        // If we have vehicle location, move camera there
        _uiState.value.vehicleLocation?.let { location ->
            map.moveCamera(CameraUpdateFactory.newLatLngZoom(location, 14f))
        }
        // Load nearby stations when map is ready
        loadNearbyStations()
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
                // Get stored user_id
                val userId = settingsDataStore.userId.first()
                if (userId == null) {
                    android.util.Log.e("HomeViewModel", "No user_id found, cannot check Tesla status")
                    _uiState.update { it.copy(isLoading = false, vehicleConnected = false) }
                    return@launch
                }
                android.util.Log.d("HomeViewModel", "Checking Tesla status for user: $userId")

                // Check Tesla status
                val teslaStatus = backendApi.checkTeslaStatus(userId)
                if (!teslaStatus.linked) {
                    _uiState.update { it.copy(isLoading = false, vehicleConnected = false) }
                    return@launch
                }

                // Get vehicles
                val vehicles = backendApi.getVehicles()
                if (vehicles.isEmpty()) {
                    _uiState.update { it.copy(isLoading = false, vehicleConnected = false) }
                    return@launch
                }

                val vehicle = vehicles.first()
                currentVehicleId = vehicle.id

                // Try to get vehicle state
                try {
                    val state = backendApi.getVehicleState(vehicle.id)
                    val location = if (state.latitude != null && state.longitude != null) {
                        LatLng(state.latitude, state.longitude)
                    } else null

                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            vehicleConnected = true,
                            batteryLevel = state.batteryLevel,
                            vehicleLocation = location,
                            departureSOC = state.batteryLevel ?: 80,
                            vehicleDisplayState = VehicleDisplayState(
                                displayName = vehicle.displayName,
                                stateText = getStateText(vehicle.state, state.chargingState),
                                batteryLevel = state.batteryLevel ?: 0,
                                rangeKm = state.batteryRange?.toInt() ?: 0
                            )
                        )
                    }

                    // Move map to vehicle location
                    location?.let { loc ->
                        aMap?.moveCamera(CameraUpdateFactory.newLatLngZoom(loc, 14f))
                    }

                    // Load recent trips
                    loadRecentTrips()

                } catch (e: Exception) {
                    // Vehicle might be offline
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            vehicleConnected = true,
                            vehicleDisplayState = VehicleDisplayState(
                                displayName = vehicle.displayName,
                                stateText = "Offline",
                                batteryLevel = 0,
                                rangeKm = 0
                            )
                        )
                    }
                }

            } catch (e: Exception) {
                _uiState.update {
                    it.copy(isLoading = false, error = e.message)
                }
            }
        }
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

    private fun planRoute() {
        val destination = _uiState.value.destination ?: return
        val origin = _uiState.value.vehicleLocation ?: return

        viewModelScope.launch {
            _uiState.update { it.copy(pageState = HomePageState.ROUTE_PREVIEW) }

            // TODO: Implement actual route planning using AMap SDK
            // For now, set placeholder route data
            _uiState.update {
                it.copy(
                    routeData = RouteData(
                        destinationName = destination.name,
                        totalDistanceKm = 0.0,
                        totalDuration = "--",
                        arrivalSoc = 20,
                        chargingStops = emptyList()
                    )
                )
            }
        }
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
            chargingState == "Charging" -> "Charging"
            chargingState == "Complete" -> "Charge Complete"
            vehicleState == "online" -> "Online"
            vehicleState == "asleep" -> "Asleep"
            else -> "Offline"
        }
    }
}
