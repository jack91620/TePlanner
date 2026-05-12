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
import androidx.compose.foundation.clickable
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
                .fillMaxSize()
                .testTag("battery_view"),
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
                else -> Content(
                    state = state,
                    vehicleId = hub.vehicle?.id,
                    currentChargeLimit = hub.vehicleState?.chargeLimitSoc,
                    onApplyChargeLimit = { hubVm.applySuggestedChargeLimit(it) },
                )
            }
        }
    }
}

@Composable
private fun Content(
    state: ChargingStatsViewModel.State,
    vehicleId: String?,
    currentChargeLimit: Int?,
    onApplyChargeLimit: (Int) -> Unit,
) {
    // 2026-05-11 B4: tap-to-detail mirror of iOS ChargingSessionDetailView.
    // Holds the session whose detail dialog is currently open; null = none.
    var detailSession by remember { mutableStateOf<ChargingSessionResponse?>(null) }

    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (vehicleId != null) {
            item {
                ChargeLimitCard(
                    currentChargeLimit = currentChargeLimit,
                    onApply = onApplyChargeLimit,
                )
                Spacer(Modifier.height(8.dp))
            }
        }
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
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { detailSession = s }
                        .testTag("session_row_${s.id}"),
                ) {
                    SessionRow(s)
                }
                HorizontalDivider()
            }
        }
    }

    detailSession?.let { session ->
        ChargingSessionDetailDialog(
            session = session,
            onDismiss = { detailSession = null },
        )
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
                // 2026-05-11: parity with iOS — finalized session
                // always shows "充电完成" (true/false collapsed; the
                // boolean is unreliable across closer-handled rows).
                if (s.endedAsComplete != null) append(" · 充电完成")
            }.ifBlank { s.source },
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}


/**
 * Tap-to-open detail dialog — Android mirror of iOS
 * ChargingSessionDetailView. AlertDialog instead of full sheet so
 * the user stays in BatteryView context.
 */
@Composable
private fun ChargingSessionDetailDialog(
    session: ChargingSessionResponse,
    onDismiss: () -> Unit,
) {
    val isOngoing = session.endedAt == null
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier.testTag("session_detail_view"),
        title = {
            Text(
                if (isOngoing) "充电中" else "充电完成",
                style = MaterialTheme.typography.titleLarge,
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                DetailKV("开始", formatDate(session.startedAt))
                session.endedAt?.let { DetailKV("结束", formatDate(it)) }
                session.durationMinutes?.let {
                    DetailKV("时长", formatMinutes(it))
                }
                HorizontalDivider()
                if (session.startSoc != null) DetailKV("起始 SOC", "${session.startSoc}%")
                if (session.endSoc != null) DetailKV("结束 SOC", "${session.endSoc}%")
                session.socDelta?.let {
                    if (it != 0) DetailKV("电量增加", "+$it%", emphasize = true)
                }
                session.rangeAddedKm?.let { range ->
                    if (range > 0) {
                        HorizontalDivider()
                        DetailKV("新增续航", "+${range.toInt()} km", emphasize = true)
                    }
                }
                session.energyAddedKwh?.let { kwh ->
                    DetailKV("充入电量", "%.1f kWh".format(kwh))
                }
                session.locationName?.let {
                    HorizontalDivider()
                    DetailKV("地点", it)
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.testTag("session_detail_close"),
            ) { Text("完成") }
        },
    )
}


@Composable
private fun DetailKV(key: String, value: String, emphasize: Boolean = false) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            key,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Text(
            value,
            style = if (emphasize) MaterialTheme.typography.titleSmall
                    else MaterialTheme.typography.bodyMedium,
            fontWeight = if (emphasize) FontWeight.SemiBold else FontWeight.Normal,
            color = if (emphasize) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurface,
        )
    }
}


@Composable
private fun ChargeLimitCard(
    currentChargeLimit: Int?,
    onApply: (Int) -> Unit,
) {
    // Seed the slider from the car's actual current limit (defaults
    // to 80 only when the car state hasn't arrived yet). When the
    // API later resolves, sync once via LaunchedEffect — same fix
    // as iOS commit e748fd3 (the state-init race that would let
    // the user accidentally raise their limit by tapping apply on
    // a stale-default slider position).
    var manualLimit by remember { mutableStateOf((currentChargeLimit ?: 80).toFloat()) }
    var lastSyncedCurrent by remember { mutableStateOf<Int?>(null) }
    androidx.compose.runtime.LaunchedEffect(currentChargeLimit) {
        // Sync the slider to the real limit when the API arrives —
        // but only if the user hasn't moved it since the last sync
        // (defend against clobbering a pending manual edit).
        if (currentChargeLimit != null && lastSyncedCurrent == null) {
            manualLimit = currentChargeLimit.toFloat()
            lastSyncedCurrent = currentChargeLimit
        }
    }
    val target = manualLimit.toInt()
    val unchanged = target == currentChargeLimit
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
            Text("充电限额", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            if (currentChargeLimit != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("车辆当前", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.weight(1f))
                    Text("$currentChargeLimit%", fontWeight = FontWeight.SemiBold)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("目标", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.weight(1f))
                Text(
                    "$target%",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            androidx.compose.material3.Slider(
                value = manualLimit,
                onValueChange = { manualLimit = it },
                valueRange = 50f..100f,
                steps = 9, // 50, 55, …, 100 (50→100 stepped by 5 = 10 buckets = 9 dividers)
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("manual_charge_limit_slider"),
            )
            androidx.compose.material3.Button(
                onClick = { onApply(target) },
                enabled = !unchanged,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("apply_manual_charge_limit_button"),
            ) {
                Text(if (unchanged) "当前限额已是 $target%" else "应用 $target%")
            }
            Spacer(Modifier.height(4.dp))
            Text(
                if (unchanged) "当前限额已是 $target%，无需重复发送"
                else "跳过预设直接发命令到车辆。出长途调到 100% 等一次性场景用此入口。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

private fun formatMinutes(minutes: Int): String {
    if (minutes == 0) return "—"
    if (minutes < 60) return "$minutes 分钟"
    val h = minutes / 60
    val m = minutes % 60
    return if (m == 0) "$h 小时" else "$h 小时 $m 分"
}

private fun formatDate(iso: String): String =
    runCatching {
        val instant = Instant.parse(iso)
        val zoned = instant.atZone(ZoneId.systemDefault())
        DateTimeFormatter.ofPattern("MM-dd HH:mm").format(zoned)
    }.getOrDefault(iso)
