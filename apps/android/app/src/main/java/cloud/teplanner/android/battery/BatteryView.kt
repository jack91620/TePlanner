package cloud.teplanner.android.battery

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import cloud.teplanner.android.core.network.ChargingSessionResponse
import cloud.teplanner.android.hub.HubViewModel
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Phase F.4.2 — battery / charging stats. iOS BatteryView mirror.
 *
 * v1: skip the manual charge-limit slider + suggestion (iOS exposes
 * those via /vehicles/{id}/charge-limit + /suggest-charge-limit).
 * Send-to-vehicle commands need VCP pairing first; lands in F.4
 * polish or F.5 if Tesla auth flow gets ported. For now: monthly
 * stats grid + recent session history.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BatteryView(
    onBack: () -> Unit,
    hubVm: HubViewModel = hiltViewModel(),
    vm: ChargingStatsViewModel = hiltViewModel(),
) {
    val hub by hubVm.state.collectAsState()
    val state by vm.state.collectAsState()

    androidx.compose.runtime.LaunchedEffect(hub.vehicle?.id) {
        hub.vehicle?.id?.let { vm.load(it) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("电池管理") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回")
                    }
                },
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize(),
        ) {
            when {
                state.isLoading && state.sessions.isEmpty() -> Row(
                    modifier = Modifier.fillMaxWidth().padding(20.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    CircularProgressIndicator(modifier = Modifier.height(20.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.height(8.dp))
                    Text("加载中…")
                }
                hub.vehicle == null -> Text(
                    "请先绑定 Tesla 车辆",
                    modifier = Modifier.padding(20.dp),
                    style = MaterialTheme.typography.bodyMedium,
                )
                state.error != null -> Text(
                    state.error ?: "",
                    modifier = Modifier.padding(20.dp),
                    color = MaterialTheme.colorScheme.error,
                )
                else -> Content(state)
            }
        }
    }
}

@Composable
private fun Content(state: ChargingStatsViewModel.State) {
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (state.months.isNotEmpty()) {
            item { SectionHeader("月度统计") }
            items(state.months, key = { it.label }) { m ->
                Card {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(m.label,
                             style = MaterialTheme.typography.titleMedium,
                             fontWeight = FontWeight.SemiBold,
                             modifier = Modifier.padding(end = 12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text("${"%.1f".format(m.energyKwh)} kWh · " +
                                "${m.sessions} 次 · ${m.durationMinutes} 分钟",
                                style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
            }
            item { Spacer(Modifier.height(8.dp)) }
            item { SectionHeader("最近充电记录") }
        }
        if (state.sessions.isEmpty()) {
            item {
                Text("暂无充电记录",
                     style = MaterialTheme.typography.bodyMedium,
                     color = MaterialTheme.colorScheme.onSurfaceVariant,
                     modifier = Modifier.padding(20.dp))
            }
        } else {
            items(state.sessions, key = { it.id }) { s ->
                Card { SessionRow(s) }
                HorizontalDivider()
            }
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(vertical = 4.dp),
    )
}

@Composable
private fun SessionRow(s: ChargingSessionResponse) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                formatDate(s.startedAt),
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.weight(1f),
            )
            s.energyAddedKwh?.let {
                Text("${"%.1f".format(it)} kWh",
                     style = MaterialTheme.typography.labelMedium,
                     color = MaterialTheme.colorScheme.primary)
            }
        }
        Text(
            buildString {
                if (s.startSoc != null && s.endSoc != null) {
                    append("${s.startSoc}% → ${s.endSoc}%")
                }
                s.durationMinutes?.let { append(" · ${it} 分钟") }
                s.locationName?.let { append(" · $it") }
            }.ifBlank { s.source },
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private fun formatDate(iso: String): String =
    runCatching {
        val instant = Instant.parse(iso)
        val zoned = instant.atZone(ZoneId.systemDefault())
        DateTimeFormatter.ofPattern("MM-dd HH:mm").format(zoned)
    }.getOrDefault(iso)
