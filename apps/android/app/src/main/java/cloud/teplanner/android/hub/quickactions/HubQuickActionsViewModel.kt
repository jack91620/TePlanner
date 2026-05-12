package cloud.teplanner.android.hub.quickactions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.InvokeCapabilityRequest
import cloud.teplanner.android.core.network.VehiclesApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Bridge between [HubActionsStore] (data) and the Composable section
 * (presentation). Owns:
 *   - load() on first construction
 *   - runAction(actionId, vehicleId) → walks the action's steps,
 *     invoking each capability in sequence, sleeping the configured
 *     `delay_ms_after` between steps. Mirrors iOS `HubActionsStore.run`.
 *
 * runState surfaces inline so the Hub can show "正在 X..." / 失败
 * feedback adjacent to the tile that was tapped.
 */
@HiltViewModel
class HubQuickActionsViewModel @Inject constructor(
    val store: HubActionsStore,
    private val vehiclesApi: VehiclesApi,
) : ViewModel() {

    sealed class RunState {
        object Idle : RunState()
        data class Running(val actionId: String) : RunState()
        data class Failed(val actionId: String, val stepIndex: Int, val message: String) : RunState()
        data class Succeeded(val actionId: String) : RunState()
    }

    private val _runState = MutableStateFlow<RunState>(RunState.Idle)
    val runState: StateFlow<RunState> = _runState.asStateFlow()

    init {
        viewModelScope.launch { store.load() }
    }

    /// Walks the action's steps. Aborts on first failure. Returns
    /// when all steps fire successfully (or one fails).
    fun runAction(actionId: String, vehicleId: String?) {
        if (vehicleId == null) {
            _runState.value = RunState.Failed(
                actionId = actionId, stepIndex = 0, message = "未找到绑定车辆",
            )
            return
        }
        val action = store.action(actionId) ?: run {
            _runState.value = RunState.Failed(
                actionId = actionId, stepIndex = 0, message = "动作已删除",
            )
            return
        }
        _runState.value = RunState.Running(actionId)
        viewModelScope.launch {
            for ((idx, step) in action.steps.withIndex()) {
                val result = runCatching {
                    vehiclesApi.invokeCapability(
                        vehicleId = vehicleId,
                        body = InvokeCapabilityRequest(
                            capability = step.capability,
                            params = step.params,
                        ),
                    )
                }
                if (result.isFailure) {
                    val msg = result.exceptionOrNull()?.message ?: "未知错误"
                    _runState.value = RunState.Failed(
                        actionId = actionId, stepIndex = idx, message = msg,
                    )
                    return@launch
                }
                step.delayMsAfter?.takeIf { it > 0 }?.let { ms ->
                    if (idx < action.steps.size - 1) {
                        delay(ms.toLong())
                    }
                }
            }
            _runState.value = RunState.Succeeded(actionId)
        }
    }

    fun clearRunState() {
        _runState.value = RunState.Idle
    }
}
