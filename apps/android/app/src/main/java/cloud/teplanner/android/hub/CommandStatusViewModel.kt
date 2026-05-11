package cloud.teplanner.android.hub

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.PendingCommandRow
import cloud.teplanner.android.core.network.QueuedCommandRow
import cloud.teplanner.android.core.network.VehiclesApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import javax.inject.Inject

/**
 * Mirror of iOS CommandStatusStore (TePlannerKit/Services/CommandStatusStore.swift).
 *
 * Owns the most-recent pending / queued command rows + drives the
 * converge poll after any dispatch. Hub renders a banner from this
 * VM's state; chip dispatchers (in HubViewModel) trigger
 * `pollUntilSettled()` after their HTTP POST returns success.
 *
 * iOS behaviour:
 *   - 12-second deadline, 1-second poll cadence.
 *   - Show row while status == pending or first 3s post-resolution.
 *   - Queued rows (sleep-aware queue) have 5s afterglow on
 *     sent/dropped.
 *   - Transient network failures don't clear known-good banner —
 *     only authoritative success responses mutate state.
 */
@HiltViewModel
class CommandStatusViewModel @Inject constructor(
    private val vehiclesApi: VehiclesApi,
) : ViewModel() {

    data class State(
        val activePending: PendingCommandRow? = null,
        val activeQueued: QueuedCommandRow? = null,
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    /** Track when we first saw the pending row reach a terminal
     *  status so we can clear the banner 3s later. */
    private var pendingResolvedAt: Instant? = null

    fun refresh() {
        viewModelScope.launch { refreshOnce() }
    }

    /** Caller fires-and-forgets in a coroutine; UI updates via the
     *  StateFlow. Mirrors iOS pollUntilSettled. */
    fun pollUntilSettled() {
        viewModelScope.launch {
            val deadline = System.currentTimeMillis() + 12_000L
            refreshOnce()
            while (System.currentTimeMillis() < deadline) {
                delay(1_000L)
                refreshOnce()
                if (_state.value.activePending == null) break
            }
        }
    }

    private suspend fun refreshOnce() {
        runCatching { vehiclesApi.pendingCommands() }
            .onSuccess { resp -> applyPending(resp.pending) }
        runCatching { vehiclesApi.queuedCommands() }
            .onSuccess { resp -> applyQueued(resp.queued) }
        // Transient failure: keep prior state (don't flicker banner on
        // every 502). Same rule as iOS CommandStatusStore.
    }

    private fun applyPending(rows: List<PendingCommandRow>) {
        val latest = rows.firstOrNull()
        if (latest == null) {
            _state.update { it.copy(activePending = null) }
            pendingResolvedAt = null
            return
        }
        val isResolved = latest.status != "pending"
        if (isResolved && pendingResolvedAt == null) {
            pendingResolvedAt = Instant.now()
        }
        val resolvedTs = pendingResolvedAt
        val pastFlash = isResolved && resolvedTs != null &&
            Instant.now().isAfter(resolvedTs.plusSeconds(3))
        if (pastFlash) {
            _state.update { it.copy(activePending = null) }
            pendingResolvedAt = null
        } else {
            _state.update { it.copy(activePending = latest) }
            if (!isResolved) pendingResolvedAt = null
        }
    }

    private fun applyQueued(rows: List<QueuedCommandRow>) {
        val row = rows.firstOrNull { r ->
            if (r.status == "queued") return@firstOrNull true
            // Brief afterglow on resolution (5s).
            val resolvedRaw = r.sentAt ?: r.droppedAt ?: return@firstOrNull false
            runCatching { Instant.parse(resolvedRaw) }
                .map { it.isAfter(Instant.now().minusSeconds(5)) }
                .getOrDefault(false)
        }
        _state.update { it.copy(activeQueued = row) }
    }
}
