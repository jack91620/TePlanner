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
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.VpnKey
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.ui.graphics.Color
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
    commandStatus: CommandStatusViewModel = hiltViewModel(),
) {
    val account by auth.account.collectAsState()
    val state by hub.state.collectAsState()
    val departureState by departure.state.collectAsState()
    val commandStatusState by commandStatus.state.collectAsState()
    var showDepartureSheet by remember { mutableStateOf(false) }
    var menuExpanded by remember { mutableStateOf(false) }
    val ctx = androidx.compose.ui.platform.LocalContext.current

    // Trigger converge poll after any chip command success — mirror
    // of iOS HubView.applyChipCommandResult kicking pollUntilSettled.
    androidx.compose.runtime.LaunchedEffect(state.chipStatus) {
        if (state.chipStatus is HubViewModel.ChipStatus.Sent) {
            commandStatus.pollUntilSettled()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Tautomation") },
                actions = {
                    IconButton(onClick = { hub.refresh() }) {
                        Icon(Icons.Filled.Refresh, contentDescription = "刷新")
                    }
                    IconButton(
                        onClick = { menuExpanded = true },
                        modifier = Modifier.testTag("hub_menu_button"),
                    ) {
                        Icon(Icons.Filled.MoreVert, contentDescription = "更多")
                    }
                    DropdownMenu(
                        expanded = menuExpanded,
                        onDismissRequest = { menuExpanded = false },
                    ) {
                        DropdownMenuItem(
                            text = { Text("配对车辆控制") },
                            leadingIcon = { Icon(Icons.Filled.VpnKey, null) },
                            onClick = {
                                menuExpanded = false
                                openVcpPairingUrl(ctx)
                            },
                            modifier = Modifier.testTag("hub_menu_pair_vehicle"),
                        )
                        DropdownMenuItem(
                            text = { Text("退出登录") },
                            leadingIcon = { Icon(Icons.AutoMirrored.Filled.Logout, null) },
                            onClick = {
                                menuExpanded = false
                                auth.logout()
                                onLoggedOut()
                            },
                            modifier = Modifier.testTag("hub_menu_logout"),
                        )
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
            HubWelcomeBannerHosted()
            VcpPairingPrompt(showWhenVehicleKnown = state.vehicle != null)
            VehicleStatusCard(state = state)
            PermissionBanner()
            CommandStatusBanner(state = commandStatusState)
            HubChargeLimitCard(
                suggestion = state.chargeLimitSuggestion,
                onApply = hub::applySuggestedChargeLimit,
            )
            HubStatusChips(
                state = state.vehicleState,
                chipStatus = state.chipStatus,
                onCloseClimateKeeper = hub::closeClimateKeeper,
                onCloseSentry = hub::closeSentry,
                onLock = hub::lock,
                onDismissStatus = hub::dismissChipStatus,
            )
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
                val label = acc.email ?: "用户 ID：${acc.userId}"
                Text(
                    "登录账号：$label",
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
        modifier = Modifier.fillMaxWidth().testTag("hub_status_card"),
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


/**
 * Hub status chips — mirror of iOS HubView.statusChip + chipsSection.
 *
 * Show one chip per ON state (露营 / 哨兵 / 未锁 / 充电中 etc.) that
 * the user might want to act on. Tap → confirmation alert → command
 * dispatch via HubViewModel. Status feedback is inline (sending →
 * sent → idle after 2.5s, or sent → failed with retry).
 *
 * Only chips with a tappable `action` show — read-only chips
 * (cabin overheat, charging) are display-only with no confirm.
 */
@Composable
private fun HubStatusChips(
    state: VehicleStateResponse?,
    chipStatus: HubViewModel.ChipStatus,
    onCloseClimateKeeper: () -> Unit,
    onCloseSentry: () -> Unit,
    onLock: () -> Unit,
    onDismissStatus: () -> Unit,
) {
    if (state == null) return
    var pending: PendingChipAction? by remember { mutableStateOf(null) }

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // 露营 / 宠物 / 保持空调 — all funnel to "关闭空调保持"
            when (state.climateKeeperMode) {
                1 -> chip("保持空调", testTag = "hub_chip_climate_keeper") {
                    pending = PendingChipAction(
                        title = "关闭保持空调？",
                        run = onCloseClimateKeeper,
                    )
                }
                2 -> chip("宠物模式", testTag = "hub_chip_pet_mode") {
                    pending = PendingChipAction(
                        title = "关闭宠物模式？",
                        run = onCloseClimateKeeper,
                    )
                }
                3 -> chip("露营模式", testTag = "hub_chip_camp_mode") {
                    pending = PendingChipAction(
                        title = "关闭露营模式？",
                        run = onCloseClimateKeeper,
                    )
                }
            }
            if (state.sentryMode == true) {
                chip("哨兵模式", testTag = "hub_chip_sentry") {
                    pending = PendingChipAction(
                        title = "关闭哨兵模式？",
                        run = onCloseSentry,
                    )
                }
            }
            if (state.locked == false) {
                chip("未锁车", testTag = "hub_chip_unlocked") {
                    pending = PendingChipAction(
                        title = "锁车？",
                        run = onLock,
                    )
                }
            }
        }

        // Inline status banner (mirror of iOS chipStatusBanner).
        when (val cs = chipStatus) {
            is HubViewModel.ChipStatus.Sending -> Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 1.5.dp)
                Text(cs.label, style = MaterialTheme.typography.bodySmall,
                     color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            is HubViewModel.ChipStatus.Sent -> Text(
                "✓ ${cs.label}",
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF388E3C),
            )
            is HubViewModel.ChipStatus.Failed -> Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "⚠ ${cs.message}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = onDismissStatus) { Text("关闭") }
            }
            HubViewModel.ChipStatus.Idle -> Unit
        }
    }

    pending?.let { p ->
        AlertDialog(
            onDismissRequest = { pending = null },
            title = { Text(p.title) },
            confirmButton = {
                TextButton(onClick = {
                    p.run()
                    pending = null
                }) { Text("确认") }
            },
            dismissButton = {
                TextButton(onClick = { pending = null }) { Text("取消") }
            },
        )
    }
}

private data class PendingChipAction(
    val title: String,
    val run: () -> Unit,
)

@Composable
private fun chip(label: String, testTag: String, onTap: () -> Unit) {
    androidx.compose.material3.AssistChip(
        onClick = onTap,
        label = { Text(label) },
        modifier = Modifier.testTag(testTag),
    )
}


/**
 * Banner that surfaces in-flight / recently-resolved VCP commands.
 * Mirror of iOS CommandStatusBanner — only renders when there's an
 * active pending or queued row to show.
 */
@Composable
fun CommandStatusBanner(state: CommandStatusViewModel.State) {
    val pending = state.activePending
    val queued = state.activeQueued
    if (pending == null && queued == null) return

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("command_status_banner"),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.secondaryContainer,
        ),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            pending?.let { p ->
                val (title, subtitle) = pendingText(p)
                Text(title, style = MaterialTheme.typography.titleSmall)
                Text(subtitle, style = MaterialTheme.typography.bodySmall,
                     color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            queued?.let { q ->
                val (title, subtitle) = queuedText(q)
                Text(title, style = MaterialTheme.typography.titleSmall)
                Text(subtitle, style = MaterialTheme.typography.bodySmall,
                     color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

private fun pendingText(
    p: cloud.teplanner.android.core.network.PendingCommandRow,
): Pair<String, String> {
    val verb = when (p.capability) {
        "tesla.security.set_sentry" -> "切换哨兵"
        "tesla.climate.set_keeper_mode" -> "切换空调保持"
        "tesla.security.door_lock" -> "锁车"
        "tesla.security.door_unlock" -> "解锁"
        "tesla.climate.preheat" -> "预热"
        "tesla.charging.set_limit" -> "调整充电限额"
        else -> "执行命令"
    }
    return when (p.status) {
        "confirmed" -> "已${verb}" to "车辆已确认，操作完成"
        "timed_out" -> "${verb} — 未确认" to "60 秒内未收到车辆反馈"
        else -> "正在${verb}…" to "等待车辆确认"
    }
}

private fun queuedText(
    q: cloud.teplanner.android.core.network.QueuedCommandRow,
): Pair<String, String> {
    return when (q.status) {
        "sent" -> "命令已发送" to "车辆已上线"
        "dropped" -> {
            val tail = q.error?.let { ": $it" } ?: ""
            "命令已超时" to "未在 TTL 内执行$tail"
        }
        else -> "等待车辆上线" to "下次上线时自动执行"
    }
}


/**
 * Hub-level "调高/调低充电限额到 N%" suggestion card — mirror of iOS
 * HubChargeLimitCard.
 *
 * Server (`/suggest-charge-limit`) returns a recommended percent
 * based on the user's daily/trip preferences + any upcoming
 * ScheduledDeparture. Card renders only when `alreadyMatches`
 * is false. Tap 应用 → dispatch set_charge_limit + converge poll
 * (kicked off through the chip-status flow on HubViewModel).
 */
@Composable
private fun HubChargeLimitCard(
    suggestion: cloud.teplanner.android.core.network.SuggestChargeLimitResponse?,
    onApply: (Int) -> Unit,
) {
    if (suggestion == null || suggestion.alreadyMatches) return
    val current = suggestion.currentPercent ?: return

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("hub_charge_limit_card"),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.tertiaryContainer,
        ),
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                Icons.Filled.BatteryFull,
                contentDescription = null,
                modifier = Modifier.size(24.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                val verb = if (suggestion.recommendedPercent > current) "调高" else "调低"
                Text(
                    "建议${verb}充电限额到 ${suggestion.recommendedPercent}%",
                    style = MaterialTheme.typography.titleSmall,
                )
                Text(
                    "当前 ${current}% · ${suggestion.reason}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            TextButton(
                onClick = { onApply(suggestion.recommendedPercent) },
                modifier = Modifier.testTag("hub_charge_limit_apply"),
            ) {
                Text("应用")
            }
        }
    }
}
