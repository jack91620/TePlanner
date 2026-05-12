package cloud.teplanner.android.map

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.RoutePlanSummary
import cloud.teplanner.android.core.network.RoutesApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Backs the 最近 tab inside the Map bottom drawer. Mirror of iOS
 * RecentTripsViewModel.
 */
@HiltViewModel
class RecentTripsViewModel @Inject constructor(
    private val routes: RoutesApi,
) : ViewModel() {

    data class State(
        val trips: List<RoutePlanSummary> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(State(isLoading = true))
    val state: StateFlow<State> = _state.asStateFlow()

    init { refresh() }

    fun refresh() {
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            runCatching {
                routes.listMyRoutePlans(limit = 20).routes
            }.fold(
                onSuccess = { trips ->
                    _state.update { State(trips = trips, isLoading = false) }
                },
                onFailure = { err ->
                    _state.update {
                        it.copy(isLoading = false, error = err.localizedMessage)
                    }
                },
            )
        }
    }
}
