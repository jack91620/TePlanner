package cloud.teplanner.android.departure

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.ScheduledDepartureRequest
import cloud.teplanner.android.core.network.ScheduledDepartureResponse
import cloud.teplanner.android.core.network.UserApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import javax.inject.Inject

/**
 * Phase F.4.1 — scheduled departure store. iOS counterpart:
 * `ScheduledDepartureStore`. Single row per user; backend enforces
 * UNIQUE(user_id) so we PUT to upsert, DELETE to clear.
 */
@HiltViewModel
class ScheduledDepartureViewModel @Inject constructor(
    private val api: UserApi,
) : ViewModel() {

    data class State(
        val current: ScheduledDepartureResponse? = null,
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    init { refresh() }

    fun refresh() {
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            runCatching { api.getScheduledDeparture() }
                .onSuccess { resp ->
                    _state.update { it.copy(isLoading = false, current = resp) }
                }
                .onFailure { err ->
                    _state.update { it.copy(isLoading = false, error = err.message) }
                }
        }
    }

    fun upsert(
        departureLocal: ZonedDateTime,
        leadMinutes: Int,
        targetChargeSoc: Int?,
        vehicleId: String?,
    ) {
        val utcInstant = departureLocal.toInstant()
        val iso = DateTimeFormatter.ISO_INSTANT.format(utcInstant)
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            runCatching {
                api.upsertScheduledDeparture(
                    ScheduledDepartureRequest(
                        departureAtUtc = iso,
                        leadMinutes = leadMinutes,
                        targetChargeSoc = targetChargeSoc,
                        vehicleId = vehicleId,
                        enabled = true,
                    )
                )
            }.onSuccess { resp ->
                _state.update { it.copy(isLoading = false, current = resp) }
            }.onFailure { err ->
                _state.update { it.copy(isLoading = false, error = err.message) }
            }
        }
    }

    fun clear() {
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            runCatching { api.clearScheduledDeparture() }
                .onSuccess {
                    _state.update { it.copy(isLoading = false, current = null) }
                }
                .onFailure { err ->
                    _state.update { it.copy(isLoading = false, error = err.message) }
                }
        }
    }

    companion object {
        /** Parse the backend's ISO timestamp back into the device timezone.
         *  Pydantic emits naive UTC like `2026-05-10T23:30:00` (no Z), so
         *  fall back to LocalDateTime.parse + assume UTC if Instant.parse
         *  rejects the string.
         */
        fun displayLocal(utcIso: String): String {
            val instant = runCatching { Instant.parse(utcIso) }.getOrNull()
                ?: runCatching {
                    LocalDateTime.parse(utcIso).toInstant(ZoneOffset.UTC)
                }.getOrNull()
                ?: return utcIso
            val zoned = instant.atZone(ZoneId.systemDefault())
            return DateTimeFormatter.ofPattern("MM-dd HH:mm").format(zoned)
        }
    }
}
