package cloud.teplanner.android.battery

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.ChargingSessionResponse
import cloud.teplanner.android.core.network.SessionsApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.YearMonth
import java.time.ZoneId
import javax.inject.Inject

/**
 * Phase F.4.2 — pulls the user's recent charging sessions and rolls
 * them up into monthly aggregates (energy_added_kwh, count, total
 * duration). iOS counterpart: `ChargingStatsViewModel`.
 */
@HiltViewModel
class ChargingStatsViewModel @Inject constructor(
    private val api: SessionsApi,
) : ViewModel() {

    data class MonthStat(
        val ym: YearMonth,
        val energyKwh: Double,
        val sessions: Int,
        val durationMinutes: Int,
    ) {
        val label: String get() = "%d-%02d".format(ym.year, ym.monthValue)
    }

    data class State(
        val sessions: List<ChargingSessionResponse> = emptyList(),
        val months: List<MonthStat> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    fun load(vehicleId: String) {
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            runCatching { api.list(vehicleId, limit = 200) }
                .onSuccess { resp ->
                    val rolled = rollUp(resp.sessions)
                    _state.update {
                        it.copy(isLoading = false, sessions = resp.sessions, months = rolled)
                    }
                }
                .onFailure { err ->
                    _state.update { it.copy(isLoading = false, error = err.message) }
                }
        }
    }

    private fun rollUp(sessions: List<ChargingSessionResponse>): List<MonthStat> {
        val zone = ZoneId.systemDefault()
        return sessions
            .groupBy { s ->
                val instant = runCatching { Instant.parse(s.startedAt) }.getOrNull()
                    ?: return@groupBy YearMonth.now()
                YearMonth.from(instant.atZone(zone))
            }
            .map { (ym, group) ->
                MonthStat(
                    ym = ym,
                    energyKwh = group.sumOf { it.energyAddedKwh ?: 0.0 },
                    sessions = group.size,
                    durationMinutes = group.sumOf { it.durationMinutes ?: 0 },
                )
            }
            .sortedByDescending { it.ym }
    }
}
