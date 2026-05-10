package cloud.teplanner.android.map

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.ChargingPlanRequest
import cloud.teplanner.android.core.network.ChargingStopResponse
import cloud.teplanner.android.core.network.Coordinate
import cloud.teplanner.android.core.network.LocationInput
import cloud.teplanner.android.core.network.PlaceResult
import cloud.teplanner.android.core.network.RouteOnlyRequest
import cloud.teplanner.android.core.network.RoutesApi
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
) : AndroidViewModel(app) {

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
}
