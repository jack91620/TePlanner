package cloud.teplanner.android.map

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.ChargingApi
import cloud.teplanner.android.core.network.ChargingStation
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Phase F.3.2 — bottom-sheet charger list. Calls backend
 * `/charging/nearby` (proxies AMap Web Service POI search) and
 * keeps a filter chip selection. Empty result = backend has no
 * AMAP_WEB_API_KEY configured (returns count=0); the UI surfaces
 * that gracefully.
 */
@HiltViewModel
class NearbyChargersViewModel @Inject constructor(
    private val api: ChargingApi,
) : ViewModel() {

    enum class Filter(val wire: String, val label: String) {
        ALL("all", "全部"),
        SUPERCHARGER("supercharger", "超充"),
        DESTINATION("destination", "目的地"),
        SERVICE("service", "第三方"),
    }

    data class State(
        val center: Pair<Double, Double>? = null,
        val filter: Filter = Filter.ALL,
        val stations: List<ChargingStation> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    fun setCenter(lat: Double, lng: Double) {
        if (_state.value.center?.first == lat && _state.value.center?.second == lng) return
        _state.update { it.copy(center = lat to lng) }
        refresh()
    }

    fun setFilter(filter: Filter) {
        if (_state.value.filter == filter) return
        _state.update { it.copy(filter = filter) }
        refresh()
    }

    fun refresh() {
        val center = _state.value.center ?: return
        val type = _state.value.filter.wire
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            runCatching {
                api.nearby(latitude = center.first, longitude = center.second, type = type)
            }.onSuccess { resp ->
                _state.update { it.copy(isLoading = false, stations = resp.stations) }
            }.onFailure { err ->
                _state.update { it.copy(isLoading = false, error = err.message) }
            }
        }
    }
}
