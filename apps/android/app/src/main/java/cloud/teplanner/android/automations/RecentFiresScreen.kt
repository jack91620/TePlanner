package cloud.teplanner.android.automations

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.History
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.AutomationsApi
import cloud.teplanner.android.core.network.RecentFireEntry
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import javax.inject.Inject

/**
 * 「活动」— recent rule-fire timeline. Mirrors iOS RecentFiresView.
 * Reachable from the Hub menu / settings (wiring landing in next
 * navigation pass). Loads up to 50 most recent fires from backend.
 */
@HiltViewModel
class RecentFiresViewModel @Inject constructor(
    private val api: AutomationsApi,
) : ViewModel() {

    data class State(
        val fires: List<RecentFireEntry> = emptyList(),
        val loading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(State(loading = true))
    val state: StateFlow<State> = _state.asStateFlow()

    init { load() }

    fun load() {
        _state.update { it.copy(loading = true) }
        viewModelScope.launch {
            runCatching { api.recentFires(limit = 50) }
                .onSuccess { resp ->
                    _state.update { State(fires = resp.fires) }
                }
                .onFailure { err ->
                    _state.update { it.copy(loading = false, error = err.message) }
                }
        }
    }
}


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecentFiresScreen(
    onBack: () -> Unit,
    vm: RecentFiresViewModel = hiltViewModel(),
) {
    val state by vm.state.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("活动") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .testTag("recent_fires_view"),
        ) {
            when {
                state.loading && state.fires.isEmpty() -> Row(
                    Modifier.fillMaxWidth().padding(20.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    CircularProgressIndicator(strokeWidth = 2.dp)
                }
                state.error != null -> Text(
                    state.error ?: "",
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(20.dp),
                )
                state.fires.isEmpty() -> EmptyState()
                else -> LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.fires, key = { "${it.kind}-${it.pushedAt}" }) { fire ->
                        Card(modifier = Modifier.fillMaxWidth()) {
                            FireRow(fire)
                        }
                    }
                }
            }
        }
    }
}


@Composable
private fun EmptyState() {
    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            Icons.Filled.History,
            contentDescription = null,
            modifier = Modifier.padding(8.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            "还没有触发记录",
            style = MaterialTheme.typography.titleMedium,
        )
        Text(
            "当某条自动化规则首次推送通知，就会出现在这里。",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}


@Composable
private fun FireRow(fire: RecentFireEntry) {
    Column(modifier = Modifier.fillMaxWidth().padding(12.dp)) {
        Text(
            kindToChinese(fire.kind),
            style = MaterialTheme.typography.titleSmall,
        )
        Text(
            formatTime(fire.pushedAt),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        fire.clearedAt?.let {
            Text(
                "已解除 · ${formatTime(it)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}


private fun kindToChinese(kind: String): String = when (kind) {
    "campMode" -> "露营模式"
    "sentryMode" -> "哨兵模式"
    "cabinOverheat" -> "座舱过热"
    "chargeComplete" -> "充电完成"
    "leftUnlocked" -> "停车未锁"
    "closureLeftOpen" -> "车窗 / 后备箱未关"
    "lowBattery" -> "电量过低"
    "weekdayPreheat" -> "工作日预热"
    "geofenceEnter" -> "进入区域"
    "geofenceExit" -> "离开区域"
    "connectivity" -> "网络变化"
    "waitResolved" -> "条件已满足"
    else -> kind
}


private fun formatTime(iso: String): String = runCatching {
    val instant = Instant.parse(iso)
    val zoned = instant.atZone(ZoneId.systemDefault())
    DateTimeFormatter.ofPattern("MM-dd HH:mm").format(zoned)
}.getOrDefault(iso)
