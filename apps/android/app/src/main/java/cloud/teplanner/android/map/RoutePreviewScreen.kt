package cloud.teplanner.android.map

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import cloud.teplanner.android.core.network.LocationInput
import cloud.teplanner.android.core.network.PlaceResult
import cloud.teplanner.android.hub.HubViewModel

/**
 * Phase F.3.3 — route preview. Origin defaults to vehicle position
 * (or 北京天安门 fallback); destination is searched by keyword via
 * `/routes/search`. Tapping "规划路线" triggers the 3-step
 * orchestration in [RoutePreviewViewModel].
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoutePreviewScreen(
    onBack: () -> Unit,
    hubVm: HubViewModel = hiltViewModel(),
    vm: RoutePreviewViewModel = hiltViewModel(),
) {
    val hubState by hubVm.state.collectAsState()
    val state by vm.state.collectAsState()
    var destinationQuery by remember { mutableStateOf("") }
    var pickerTarget by remember { mutableStateOf(PickerTarget.NONE) }

    androidx.compose.runtime.LaunchedEffect(hubState.vehicleState) {
        val vs = hubState.vehicleState
        if (state.origin == null && vs?.latitude != null && vs.longitude != null) {
            vm.setOrigin(LocationInput(
                name = vs.displayName ?: "我的车辆",
                latitude = vs.latitude!!, longitude = vs.longitude!!,
            ))
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("路线规划") },
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
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            EndpointCard(
                label = "起点",
                value = state.origin?.name ?: state.origin?.let {
                    "${it.latitude.format(4)}, ${it.longitude.format(4)}"
                } ?: "未设置 — 默认使用车辆位置",
                onEdit = {
                    pickerTarget = PickerTarget.ORIGIN
                    destinationQuery = ""
                },
            )
            EndpointCard(
                label = "终点",
                value = state.destination?.name
                    ?: state.destination?.let {
                        "${it.latitude.format(4)}, ${it.longitude.format(4)}"
                    } ?: "请选择终点",
                onEdit = {
                    pickerTarget = PickerTarget.DESTINATION
                    destinationQuery = ""
                },
            )

            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("出发电量 ${state.initialSoc}%",
                         style = MaterialTheme.typography.titleSmall)
                    Slider(
                        value = state.initialSoc.toFloat(),
                        onValueChange = { vm.setInitialSoc(it.toInt()) },
                        valueRange = 10f..100f,
                        steps = 9,
                    )
                }
            }

            Button(
                onClick = { vm.plan() },
                enabled = state.origin != null && state.destination != null && !state.isLoading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (state.isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                    )
                    Spacer(Modifier.size(8.dp))
                }
                Text(if (state.isLoading) "规划中…" else "规划路线")
            }

            state.error?.let { err ->
                Text(err, color = MaterialTheme.colorScheme.error)
            }

            if (state.totalDistanceKm != null) {
                ResultCard(state)
            }

            if (pickerTarget != PickerTarget.NONE) {
                PlacePickerSheet(
                    title = if (pickerTarget == PickerTarget.ORIGIN) "选择起点" else "选择终点",
                    query = destinationQuery,
                    onQueryChange = { q ->
                        destinationQuery = q
                        vm.search(q, around = state.origin?.let {
                            cloud.teplanner.android.core.network.Coordinate(
                                it.latitude, it.longitude,
                            )
                        })
                    },
                    isSearching = state.isSearching,
                    results = state.searchResults,
                    onPick = { result ->
                        val loc = LocationInput(
                            name = result.name,
                            latitude = result.latitude,
                            longitude = result.longitude,
                        )
                        if (pickerTarget == PickerTarget.ORIGIN) vm.setOrigin(loc)
                        else vm.setDestination(loc)
                        vm.clearSearch()
                        destinationQuery = ""
                        pickerTarget = PickerTarget.NONE
                    },
                    onDismiss = {
                        vm.clearSearch()
                        destinationQuery = ""
                        pickerTarget = PickerTarget.NONE
                    },
                )
            }
        }
    }
}

private enum class PickerTarget { NONE, ORIGIN, DESTINATION }

@Composable
private fun EndpointCard(
    label: String,
    value: String,
    onEdit: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onEdit),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.LocationOn, contentDescription = null,
                 tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.size(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(label, style = MaterialTheme.typography.labelMedium,
                     color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(value, style = MaterialTheme.typography.bodyLarge, maxLines = 2)
            }
        }
    }
}

@Composable
private fun ResultCard(state: RoutePreviewViewModel.State) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp),
               verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("路线摘要", style = MaterialTheme.typography.titleMedium,
                 fontWeight = FontWeight.SemiBold)
            Text("总距离: ${state.totalDistanceKm?.let { "%.1f".format(it) } ?: "-"} km")
            Text("行驶时间: ${state.drivingDurationMinutes ?: "-"} 分钟")
            Text("预计到达电量: ${state.arrivalSoc ?: "-"}%")
            Text("充电站点: ${state.chargingStops.size} 个")
            state.chargingStops.forEachIndexed { i, stop ->
                HorizontalDivider()
                Column {
                    Text("${i + 1}. ${stop.name}",
                         style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "  到达 ${stop.arrivalSoc}% → 离开 ${stop.departureSoc}% · " +
                        "充电 ${stop.chargingDurationMinutes} 分 · " +
                        "${"%.1f".format(stop.distanceFromStartKm)} km",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            state.warnings.forEach { w ->
                Text("⚠ $w", style = MaterialTheme.typography.bodySmall,
                     color = MaterialTheme.colorScheme.tertiary)
            }
        }
    }
}

@Composable
private fun PlacePickerSheet(
    title: String,
    query: String,
    onQueryChange: (String) -> Unit,
    isSearching: Boolean,
    results: List<PlaceResult>,
    onPick: (PlaceResult) -> Unit,
    onDismiss: () -> Unit,
) {
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column {
                OutlinedTextField(
                    value = query,
                    onValueChange = onQueryChange,
                    placeholder = { Text("搜索地名或 POI 名称") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                // Quick-pick chips — emulator can't input Chinese via adb,
                // so these accelerate dev testing. iOS doesn't have these
                // since the SwiftUI search field accepts CJK natively.
                Row(
                    modifier = Modifier.fillMaxWidth().padding(top = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    listOf("北京天安门", "上海外滩", "杭州西湖", "南京").forEach { kw ->
                        OutlinedButton(
                            onClick = { onQueryChange(kw) },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                        ) { Text(kw, style = MaterialTheme.typography.labelSmall) }
                    }
                }
                Spacer(Modifier.height(8.dp))
                if (isSearching) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        Spacer(Modifier.size(8.dp))
                        Text("搜索中…", style = MaterialTheme.typography.bodySmall)
                    }
                } else {
                    LazyColumn(modifier = Modifier.height(280.dp)) {
                        items(results, key = { it.id ?: it.name + it.latitude }) { p ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { onPick(p) }
                                    .padding(vertical = 8.dp),
                            ) {
                                Icon(Icons.Filled.Place, contentDescription = null,
                                     tint = MaterialTheme.colorScheme.primary)
                                Spacer(Modifier.size(8.dp))
                                Column {
                                    Text(p.name,
                                         style = MaterialTheme.typography.bodyMedium)
                                    p.address?.let { Text(it,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant) }
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            OutlinedButton(onClick = onDismiss) { Text("取消") }
        },
    )
}

private fun Double.format(digits: Int): String = "%.${digits}f".format(this)
