package cloud.teplanner.android.automations

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.AutomationsApi
import cloud.teplanner.android.core.network.ReorderRequest
import cloud.teplanner.android.core.network.RuleCreateRequest
import cloud.teplanner.android.core.network.RuleResponse
import cloud.teplanner.android.core.network.RuleUpdateRequest
import kotlinx.serialization.json.JsonObject
import cloud.teplanner.android.core.network.SnoozeRecord
import cloud.teplanner.android.core.network.SnoozeRequest
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Phase F.2 — automation list + per-rule actions. Mirrors iOS
 * `AutomationRulesStore` + `BackendSnoozeStore`. Backend is the
 * single source of truth (Phase A.1/A.2/D.6); this ViewModel just
 * caches + projects state for Compose.
 */
@HiltViewModel
class AutomationsViewModel @Inject constructor(
    private val api: AutomationsApi,
) : ViewModel() {

    data class State(
        val rules: List<RuleResponse> = emptyList(),
        val snoozes: Map<String, SnoozeRecord> = emptyMap(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(State(isLoading = true))
    val state: StateFlow<State> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        _state.update { it.copy(isLoading = true) }
        viewModelScope.launch {
            runCatching {
                val rules = api.list().rules
                val snoozes = api.listSnoozes().snoozes.associateBy { it.ruleId }
                _state.update { State(rules = rules, snoozes = snoozes, isLoading = false) }
            }.onFailure { err ->
                _state.update { it.copy(isLoading = false, error = err.message) }
            }
        }
    }

    fun toggleEnabled(ruleId: String, enabled: Boolean) {
        // Optimistic — flip the cached row first, then API call.
        _state.update { s ->
            s.copy(rules = s.rules.map { if (it.id == ruleId) it.copy(enabled = enabled) else it })
        }
        viewModelScope.launch {
            runCatching {
                api.update(ruleId, RuleUpdateRequest(enabled = enabled))
            }.onFailure {
                // Roll back
                _state.update { s ->
                    s.copy(
                        rules = s.rules.map { if (it.id == ruleId) it.copy(enabled = !enabled) else it },
                        error = "更新失败：${it.message}",
                    )
                }
            }
        }
    }

    fun snooze(ruleId: String, hours: Double) {
        viewModelScope.launch {
            runCatching {
                api.snooze(ruleId, SnoozeRequest(hours = hours))
            }.fold(
                onSuccess = { rec ->
                    _state.update { it.copy(snoozes = it.snoozes + (ruleId to rec)) }
                },
                onFailure = { err ->
                    _state.update { it.copy(error = "静音失败：${err.message}") }
                },
            )
        }
    }

    fun unsnooze(ruleId: String) {
        viewModelScope.launch {
            // Optimistic — remove from cache first.
            _state.update { it.copy(snoozes = it.snoozes - ruleId) }
            runCatching { api.unsnooze(ruleId) }.onFailure { err ->
                _state.update { it.copy(error = "取消静音失败：${err.message}") }
                refresh()
            }
        }
    }

    fun delete(ruleId: String) {
        // Filter out optimistically; refresh on failure.
        val previous = _state.value.rules
        _state.update { s -> s.copy(rules = s.rules.filter { it.id != ruleId }) }
        viewModelScope.launch {
            runCatching { api.delete(ruleId) }.onFailure {
                _state.update { s -> s.copy(rules = previous, error = "删除失败：${it.message}") }
            }
        }
    }

    /// Persist a new display order. Mirrors iOS `AutomationRulesStore.reorder`.
    /// Caller passes the full ordered id list (preset + custom merged); the
    /// PUT response is the freshly-sorted full list which we swap in.
    fun reorder(orderedIds: List<String>) {
        val previous = _state.value.rules
        // Optimistic local sort by id index — keeps UI snappy during the
        // round-trip; server response replaces with the canonical order.
        val byId = previous.associateBy { it.id }
        val sorted = orderedIds.mapNotNull { byId[it] } +
            previous.filter { it.id !in orderedIds.toSet() }
        _state.update { it.copy(rules = sorted) }
        viewModelScope.launch {
            runCatching { api.reorder(ReorderRequest(ruleIds = orderedIds)) }
                .onSuccess { resp ->
                    _state.update { it.copy(rules = resp.rules) }
                }
                .onFailure { err ->
                    _state.update {
                        it.copy(rules = previous, error = "排序失败：${err.message}")
                    }
                }
        }
    }

    /** Mirror of iOS AutomationRulesStore.create. Returns new id on success. */
    suspend fun create(name: String, enabled: Boolean, spec: JsonObject): String? {
        return runCatching {
            api.create(RuleCreateRequest(name = name, enabled = enabled, spec = spec))
        }.fold(
            onSuccess = { newRule ->
                _state.update { it.copy(rules = it.rules + newRule) }
                newRule.id
            },
            onFailure = { err ->
                _state.update { it.copy(error = "创建失败：${err.message}") }
                null
            },
        )
    }

    /** Spec-only update (full spec replace). Returns true on success. */
    suspend fun updateSpec(ruleId: String, name: String, enabled: Boolean, spec: JsonObject): Boolean {
        return runCatching {
            api.update(ruleId, RuleUpdateRequest(name = name, enabled = enabled, spec = spec))
        }.fold(
            onSuccess = { updated ->
                _state.update { s ->
                    s.copy(rules = s.rules.map { if (it.id == ruleId) updated else it })
                }
                true
            },
            onFailure = { err ->
                _state.update { it.copy(error = "更新失败：${err.message}") }
                false
            },
        )
    }

    fun acknowledgeError() {
        _state.update { it.copy(error = null) }
    }

    fun rule(id: String): RuleResponse? = _state.value.rules.firstOrNull { it.id == id }
    fun snoozeFor(id: String): SnoozeRecord? = _state.value.snoozes[id]
}
