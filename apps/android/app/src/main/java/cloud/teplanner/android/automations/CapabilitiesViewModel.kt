package cloud.teplanner.android.automations

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.AutomationsApi
import cloud.teplanner.android.core.network.CapabilityInfo
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Backend capability registry cache — Android port of
 * iOS CapabilitiesStore. Fetched once per app launch from
 * /api/v1/automations/capabilities; RuleBuilder reads the list to
 * render the action-block picker for notify_and_offer.
 *
 * Hilt makes one instance per VM-scope; the picker lives inside
 * RuleBuilderScreen so two open-and-close cycles each get their own
 * instance — that's fine, the underlying GET is cheap and cached
 * server-side.
 */
@HiltViewModel
class CapabilitiesViewModel @Inject constructor(
    private val api: AutomationsApi,
) : ViewModel() {

    data class State(
        val capabilities: List<CapabilityInfo> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    init { refresh() }

    fun refresh() {
        if (_state.value.isLoading) return
        _state.update { it.copy(isLoading = true) }
        viewModelScope.launch {
            runCatching { api.capabilities() }
                .onSuccess { resp ->
                    _state.update { State(capabilities = resp.capabilities) }
                }
                .onFailure { err ->
                    _state.update { it.copy(isLoading = false, error = err.message) }
                }
        }
    }

    /** Grouped + sorted for picker rendering. Sections with no caps
     *  drop out. Caps within a section are sorted by display name. */
    fun grouped(): List<Pair<RuleDisplay.CapabilityCategory, List<CapabilityInfo>>> {
        val byCat = _state.value.capabilities
            .groupBy { RuleDisplay.capabilityCategory(it.id) }
        return RuleDisplay.CapabilityCategory.entries
            .mapNotNull { cat ->
                val list = byCat[cat] ?: return@mapNotNull null
                if (list.isEmpty()) return@mapNotNull null
                cat to list.sortedBy { RuleDisplay.capabilityName(it.id) }
            }
    }
}
