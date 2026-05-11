package cloud.teplanner.android.hub

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
// testTag import added below in the platform group; placed inline to
// keep the existing import sort stable.
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.BatteryFull
import androidx.compose.material.icons.filled.DepartureBoard
import androidx.compose.material.icons.filled.EvStation
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import cloud.teplanner.android.auth.AuthSession
import cloud.teplanner.android.core.network.VehicleStateResponse
import cloud.teplanner.android.departure.ScheduledDepartureSheet
import cloud.teplanner.android.departure.ScheduledDepartureViewModel

/**
 * Phase F.2 — Hub. Mirrors iOS HubView in slimmer form:
 *   - status card (battery + range + state)
 *   - "自动化" entry card → automation list
 *   - logout via top bar
 *
 * Map / departure / charge-limit cards land in F.3 / F.4.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HubScreen(
    onLoggedOut: () -> Unit,
    onAutomations: () -> Unit,
    onMap: () -> Unit,
    onBattery: () -> Unit,
    auth: AuthSession = hiltViewModel(),
    hub: HubViewModel = hiltViewModel(),
    departure: ScheduledDepartureViewModel = hiltViewModel(),
) {
    val account by auth.account.collectAsState()
    val state by hub.state.collectAsState()
    val departureState by departure.state.collectAsState()
    var showDepartureSheet by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Tautomation") },
                actions = {
                    IconButton(onClick = { hub.refresh() }) {
                        Icon(Icons.Filled.Refresh, contentDescription = "刷新")
                    }
                    IconButton(onClick = {
                        auth.logout()
                        onLoggedOut()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.Logout, contentDescription = "退出登录")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            VehicleStatusCard(state = state)
            EntryCard(
                title = "下次出行",
                subtitle = departureState.current?.let { d ->
                    "${ScheduledDepartureViewModel.displayLocal(d.departureAtUtc)}" +
                    " · 提前 ${d.leadMinutes} 分钟预热"
                } ?: "未设置 — 点击安排出发时间",
                icon = Icons.Filled.DepartureBoard,
                onClick = { showDepartureSheet = true },
                testTag = "hub_departure_card",
            )
            EntryCard(
                title = "充电规划",
                subtitle = "附近充电桩 · 路线规划",
                icon = Icons.Filled.EvStation,
                onClick = onMap,
                testTag = "hub_entry_planning",
            )
            EntryCard(
                title = "自动化提醒",
                subtitle = "管理预设规则与自定义触发",
                icon = Icons.Filled.AutoAwesome,
                onClick = onAutomations,
                testTag = "hub_entry_automations",
            )
            EntryCard(
                title = "电池管理",
                subtitle = "充电记录 · 月度统计",
                icon = Icons.Filled.BatteryFull,
                onClick = onBattery,
                testTag = "hub_entry_battery",
            )
            Spacer(modifier = Modifier.height(8.dp))
            account?.let { acc ->
                Text(
                    "登录账号：${acc.email}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        if (showDepartureSheet) {
            ScheduledDepartureSheet(
                current = departureState.current,
                onSave = { dt, lead, soc ->
                    departure.upsert(
                        departureLocal = dt,
                        leadMinutes = lead,
                        targetChargeSoc = soc,
                        vehicleId = state.vehicle?.id,
                    )
                },
                onClear = { departure.clear() },
                onDismiss = { showDepartureSheet = false },
            )
        }
    }
}

@Composable
private fun VehicleStatusCard(state: HubViewModel.State) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
        ),
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Text(
                state.vehicle?.displayName ?: "我的车辆",
                style = MaterialTheme.typography.titleLarge,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                state.vehicle?.model
                    ?: state.vehicle?.vin?.let { "VIN $it" }
                    ?: "未绑定",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.75f),
            )
            Spacer(Modifier.height(16.dp))

            when {
                state.isLoading -> Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.size(8.dp))
                    Text("加载车辆状态…")
                }
                state.error != null -> Text(
                    state.error ?: "",
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                )
                state.vehicleState != null -> VehicleStateRow(state.vehicleState!!)
                else -> Text("暂无车辆状态", style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

@Composable
private fun VehicleStateRow(s: VehicleStateResponse) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.BatteryFull, contentDescription = null,
                 modifier = Modifier.size(20.dp))
            Spacer(Modifier.size(8.dp))
            Text(
                "${s.batteryLevel ?: 0}%" + (s.batteryRangeKm?.let { " · ${it.toInt()} km" } ?: ""),
                style = MaterialTheme.typography.titleMedium,
            )
        }
        if (s.batteryLevel != null) {
            LinearProgressIndicator(
                progress = { (s.batteryLevel ?: 0) / 100f },
                modifier = Modifier.fillMaxWidth().height(6.dp),
            )
        }
        s.state?.let { Text("状态: $it · 充电: ${s.chargingState ?: "?"}",
                            style = MaterialTheme.typography.bodySmall) }
    }
}

@Composable
private fun EntryCard(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
    testTag: String? = null,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .then(testTag?.let { Modifier.testTag(it) } ?: Modifier)
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier.size(40.dp),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null,
                     tint = MaterialTheme.colorScheme.primary,
                     modifier = Modifier.size(28.dp))
            }
            Spacer(Modifier.size(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text(subtitle, style = MaterialTheme.typography.bodySmall,
                     color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
