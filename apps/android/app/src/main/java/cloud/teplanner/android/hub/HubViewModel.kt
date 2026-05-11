package cloud.teplanner.android.hub

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.SetClimateKeeperRequest
import cloud.teplanner.android.core.network.SetSentryRequest
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
 *
 * 2026-05-11: chips command dispatch added so Android can match
 * iOS Hub's "tap chip → confirm → command → refresh" loop. Status
 * is surfaced inline; the full CommandStatusBanner (with converge
 * poll) is the next batch.
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
        val chipStatus: ChipStatus = ChipStatus.Idle,
    )

    /// Mirrors iOS HubView.ChipCommandStatus. Surfaced inline below
    /// the chips row; auto-clears 2.5s after success.
    sealed class ChipStatus {
        object Idle : ChipStatus()
        data class Sending(val label: String) : ChipStatus()
        data class Sent(val label: String) : ChipStatus()
        data class Failed(val message: String) : ChipStatus()
    }

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
                _state.update {
                    it.copy(
                        vehicle = primary, vehicleState = vstate,
                        isLoading = false, error = null,
                    )
                }
            }.onFailure { err ->
                _state.update { it.copy(isLoading = false, error = err.message) }
            }
        }
    }

    fun dismissChipStatus() {
        _state.update { it.copy(chipStatus = ChipStatus.Idle) }
    }

    fun closeClimateKeeper() {
        dispatchCommand("关闭空调保持中…", "已关闭空调保持") { id ->
            vehiclesApi.setClimateKeeperMode(id, SetClimateKeeperRequest(mode = 0))
        }
    }

    fun closeSentry() {
        dispatchCommand("关闭哨兵模式…", "已关闭哨兵模式") { id ->
            vehiclesApi.setSentryMode(id, SetSentryRequest(on = false))
        }
    }

    fun lock() {
        dispatchCommand("锁车中…", "已锁车") { id ->
            vehiclesApi.lockVehicle(id)
        }
    }

    private inline fun dispatchCommand(
        sendingLabel: String,
        successLabel: String,
        crossinline call: suspend (String) -> Any,
    ) {
        val vehicleId = _state.value.vehicle?.id ?: return
        _state.update { it.copy(chipStatus = ChipStatus.Sending(sendingLabel)) }
        viewModelScope.launch {
            runCatching { call(vehicleId) }
                .onSuccess {
                    _state.update { it.copy(chipStatus = ChipStatus.Sent(successLabel)) }
                    refresh()
                    // Auto-clear after 2.5s — same window as iOS.
                    kotlinx.coroutines.delay(2500)
                    _state.update { st ->
                        if (st.chipStatus is ChipStatus.Sent) {
                            st.copy(chipStatus = ChipStatus.Idle)
                        } else st
                    }
                }
                .onFailure { err ->
                    _state.update { it.copy(chipStatus = ChipStatus.Failed(err.message ?: "命令失败")) }
                }
        }
    }
}
