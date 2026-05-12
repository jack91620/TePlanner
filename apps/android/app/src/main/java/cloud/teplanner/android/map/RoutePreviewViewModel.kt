package cloud.teplanner.android.map

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.ChargingPlanRequest
import cloud.teplanner.android.core.network.ChargingStopResponse
import cloud.teplanner.android.core.network.Coordinate
import cloud.teplanner.android.core.network.LocationInput
import cloud.teplanner.android.core.network.NavigationRequest
import cloud.teplanner.android.core.network.PlaceResult
import cloud.teplanner.android.core.network.RouteOnlyRequest
import cloud.teplanner.android.core.network.RoutesApi
import cloud.teplanner.android.core.network.SaveRoutePlanChargingStop
import cloud.teplanner.android.core.network.SaveRoutePlanLocation
import cloud.teplanner.android.core.network.SaveRoutePlanRequest
import cloud.teplanner.android.core.network.VehiclesApi
import cloud.teplanner.android.util.CoordConverter
import android.util.Log
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Phase F.3.3 — three-step route preview, mirrors iOS
 * `RoutePreviewViewModel`:
 *   1. POST /routes/route → polyline
 *   2. AlongRoutePOIService.searchChargingStations → candidate POIs
 *   3. POST /routes/charging-plan → stops + arrival SOC
 *
 * No fallback — fail-fast. Empty POI list still calls step 3 (the
 * planner will return zero stops + a warning).
 */
@HiltViewModel
class RoutePreviewViewModel @Inject constructor(
    app: Application,
    private val routes: RoutesApi,
    private val vehicles: VehiclesApi,
) : AndroidViewModel(app) {

    /// Mirrors iOS RoutePreviewViewModel.SendState. UI binds to this
    /// to show the dispatch button's terminal state (sent / failed).
    sealed class SendState {
        object Idle : SendState()
        object Sending : SendState()
        object Sent : SendState()
        data class Failed(val message: String) : SendState()
    }

    data class State(
        val origin: LocationInput? = null,
        val destination: LocationInput? = null,
        val initialSoc: Int = 80,
        val polyline: List<Coordinate> = emptyList(),
        val totalDistanceKm: Double? = null,
        val drivingDurationMinutes: Int? = null,
        val chargingStops: List<ChargingStopResponse> = emptyList(),
        val arrivalSoc: Int? = null,
        val warnings: List<String> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
        val searchResults: List<PlaceResult> = emptyList(),
        val isSearching: Boolean = false,
        val sendState: SendState = SendState.Idle,
    )

    private val poiService = AlongRoutePOIService(app.applicationContext)

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    fun setOrigin(p: LocationInput) {
        _state.update { it.copy(origin = p) }
    }

    fun setDestination(p: LocationInput) {
        _state.update { it.copy(destination = p) }
    }

    fun setInitialSoc(soc: Int) {
        _state.update { it.copy(initialSoc = soc.coerceIn(0, 100)) }
    }

    fun search(keyword: String, around: Coordinate? = null) {
        if (keyword.isBlank()) {
            _state.update { it.copy(searchResults = emptyList()) }
            return
        }
        _state.update { it.copy(isSearching = true) }
        viewModelScope.launch {
            runCatching {
                routes.searchPlaces(
                    keyword = keyword,
                    location = around?.let { "${it.latitude},${it.longitude}" },
                )
            }.onSuccess { resp ->
                _state.update { it.copy(isSearching = false, searchResults = resp.results) }
            }.onFailure { err ->
                _state.update { it.copy(isSearching = false, error = err.message) }
            }
        }
    }

    fun clearSearch() {
        _state.update { it.copy(searchResults = emptyList()) }
    }

    fun plan() {
        val origin = _state.value.origin
        val destination = _state.value.destination
        if (origin == null || destination == null) {
            _state.update { it.copy(error = "请先选择起点与终点") }
            return
        }
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            runCatching {
                val routeResp = routes.route(
                    RouteOnlyRequest(origin = origin, destination = destination)
                )
                val pois = poiService.searchChargingStations(routeResp.polyline)
                val planResp = routes.chargingPlan(
                    ChargingPlanRequest(
                        polyline = routeResp.polyline.map {
                            listOf(it.latitude, it.longitude)
                        },
                        totalDistanceKm = routeResp.totalDistanceKm,
                        candidatePois = pois,
                        initialSoc = _state.value.initialSoc,
                    )
                )
                Triple(routeResp, pois, planResp)
            }.onSuccess { (route, _, plan) ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        polyline = route.polyline,
                        totalDistanceKm = route.totalDistanceKm,
                        drivingDurationMinutes = route.drivingDurationMinutes,
                        chargingStops = plan.chargingStops,
                        arrivalSoc = plan.arrivalSoc,
                        warnings = plan.warnings,
                    )
                }
            }.onFailure { err ->
                _state.update { it.copy(isLoading = false, error = err.message) }
            }
        }
    }

    fun clear() {
        _state.update {
            State(
                origin = it.origin,
                destination = it.destination,
                initialSoc = it.initialSoc,
            )
        }
    }

    /// Push the planned destination to the bound vehicle's nav system.
    /// Mirrors iOS RoutePreviewViewModel.sendToVehicle:
    ///   1. POST /vehicles/{id}/navigate
    ///   2. On success → persistToHistory() so the trip lands in 最近
    ///
    /// `vehicleId` here is the Tesla numeric vehicle id (same one iOS
    /// stores in `viewModel.vehicle?.id`). Without it the call is a
    /// no-op with sendState=Failed.
    fun sendToVehicle(vehicleId: String?) {
        if (vehicleId == null) {
            _state.update { it.copy(sendState = SendState.Failed("未选择车辆")) }
            return
        }
        val dest = _state.value.destination ?: run {
            _state.update { it.copy(sendState = SendState.Failed("未选择目的地")) }
            return
        }
        _state.update { it.copy(sendState = SendState.Sending) }
        viewModelScope.launch {
            // Destination came from AMap POI → GCJ-02. Tesla expects
            // WGS-84. Convert at the outbound boundary; otherwise
            // the car navigates to a pin ~50-200m off where the user
            // tapped on AMap. Mirrors iOS RoutePreviewViewModel
            // (commit f8f9e06ish) at the sendNavigation call site.
            val wgs = CoordConverter.gcj02ToWgs84(
                CoordConverter.LatLng(dest.latitude, dest.longitude)
            )
            val request = NavigationRequest(
                latitude = wgs.lat,
                longitude = wgs.lng,
                name = dest.name,
            )
            runCatching {
                vehicles.sendNavigation(vehicleId = vehicleId, body = request)
            }.onSuccess {
                _state.update { it.copy(sendState = SendState.Sent) }
                // Best-effort save to 最近 history. Mirror iOS
                // (commit 60b5162): failure here logs but doesn't
                // undo the Tesla nav command.
                persistToHistory()
            }.onFailure { err ->
                Log.w("RoutePreviewViewModel", "nav send failed: ${err.message}")
                _state.update {
                    it.copy(sendState = SendState.Failed(err.message ?: "发送失败"))
                }
            }
        }
    }

    /// POST /routes/save with the loaded plan's origin / dest / totals.
    /// Polyline + charging stops are omitted intentionally for v1
    /// (list view doesn't render them; light payload keeps the save
    /// fast). When the 最近 detail view ships, plumb them through.
    private fun persistToHistory() {
        val snap = _state.value
        val origin = snap.origin ?: return
        val destination = snap.destination ?: return
        viewModelScope.launch {
            runCatching {
                routes.saveRoutePlan(
                    SaveRoutePlanRequest(
                        origin = SaveRoutePlanLocation(
                            latitude = origin.latitude,
                            longitude = origin.longitude,
                            address = origin.name,
                        ),
                        destination = SaveRoutePlanLocation(
                            latitude = destination.latitude,
                            longitude = destination.longitude,
                            address = destination.name,
                        ),
                        totalDistanceKm = snap.totalDistanceKm,
                        totalDurationMinutes = snap.drivingDurationMinutes,
                    )
                )
            }.onFailure { err ->
                Log.i("RoutePreviewViewModel", "route save failed (non-fatal): ${err.message}")
            }
        }
    }
}
