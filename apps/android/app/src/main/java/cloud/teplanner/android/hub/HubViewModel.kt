package cloud.teplanner.android.hub

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.TokenStore
import cloud.teplanner.android.core.network.VehicleResponse
import cloud.teplanner.android.core.network.VehicleStateResponse
import cloud.teplanner.android.core.network.VehiclesApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Phase F.2 — Hub state. Mirrors iOS HomeViewModel: list vehicles
 * → pick primary → fetch state. Polling layer (every 30s) lands in
 * F.3 alongside the map; F.2 just does an initial fetch + manual
 * refresh button.
 */
@HiltViewModel
class HubViewModel @Inject constructor(
    private val vehiclesApi: VehiclesApi,
    private val tokenStore: TokenStore,
) : ViewModel() {

    data class State(
        val vehicle: VehicleResponse? = null,
        val vehicleState: VehicleStateResponse? = null,
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(State(isLoading = true))
    val state: StateFlow<State> = _state.asStateFlow()

    init { refresh() }

    fun refresh() {
        val userId = tokenStore.userId?.toString() ?: return
        _state.update { it.copy(isLoading = true) }
        viewModelScope.launch {
            runCatching {
                val vehicles = vehiclesApi.list(userId).vehicles
                val primary = vehicles.firstOrNull { it.isPrimary } ?: vehicles.firstOrNull()
                if (primary == null) {
                    _state.update { State(error = "未绑定 Tesla 车辆") }
                    return@launch
                }
                val vstate = runCatching { vehiclesApi.state(primary.id, userId) }.getOrNull()
                _state.update { State(vehicle = primary, vehicleState = vstate) }
            }.onFailure { err ->
                _state.update { it.copy(isLoading = false, error = err.message) }
            }
        }
    }
}
