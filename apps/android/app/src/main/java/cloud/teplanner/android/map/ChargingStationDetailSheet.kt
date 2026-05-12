package cloud.teplanner.android.map

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import cloud.teplanner.android.core.network.ChargingStation

/**
 * 充电站详情 — mirror of iOS ChargingStationDetailView. Shown when
 * the user taps a row in the 附近 tab. Surfaces the metadata the
 * backend has + two outbound actions:
 *
 *   - 规划路线到此 — closes sheet, host plans a route to this station.
 *   - 在高德地图打开 — fires amapuri:// intent, web fallback when AMap
 *     app isn't installed.
 *
 * Keeps a tight testTagsAsResourceId opt-in on the content root —
 * ModalBottomSheet renders in its own Dialog window which doesn't
 * inherit MainActivity's opt-in.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalComposeUiApi::class)
@Composable
fun ChargingStationDetailSheet(
    station: ChargingStation,
    onPlanRoute: (ChargingStation) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val ctx = LocalContext.current
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .semantics { testTagsAsResourceId = true }
                .testTag("charging_station_detail_sheet")
                .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                station.name,
                style = MaterialTheme.typography.titleLarge,
            )

            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                station.operator?.takeIf { it.isNotBlank() }?.let { op ->
                    Chip(label = op, icon = Icons.Filled.Business)
                }
                station.type?.takeIf { it.isNotBlank() }?.let { ty ->
                    Chip(label = ty, icon = Icons.Filled.Bolt)
                }
                station.distanceKm?.let { km ->
                    Chip(
                        label = "${"%.1f".format(km)} km",
                        icon = Icons.Filled.LocationOn,
                    )
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant,
                        RoundedCornerShape(12.dp),
                    )
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (station.address.isNotBlank()) {
                    InfoRow(
                        icon = Icons.Filled.LocationOn,
                        label = "地址",
                        value = station.address,
                    )
                }
                station.powerKw?.let { kw ->
                    val ports = station.totalPorts?.let { total ->
                        val avail = station.availablePorts
                        if (avail != null) "$avail/$total 个 · ${kw} kW"
                        else "$total 个 · ${kw} kW"
                    } ?: "${kw} kW"
                    HorizontalDivider()
                    InfoRow(
                        icon = Icons.Filled.Bolt,
                        label = "桩位 / 功率",
                        value = ports,
                    )
                }
                station.openHours?.takeIf { it.isNotBlank() }?.let { hours ->
                    HorizontalDivider()
                    InfoRow(
                        icon = Icons.Filled.Schedule,
                        label = "营业时间",
                        value = hours,
                    )
                }
                station.tel?.takeIf { it.isNotBlank() }?.let { tel ->
                    HorizontalDivider()
                    InfoRow(
                        icon = Icons.Filled.Phone,
                        label = "联系电话",
                        value = tel,
                    )
                }
            }

            Button(
                onClick = { onPlanRoute(station) },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("station_plan_route_button"),
            ) {
                Icon(Icons.AutoMirrored.Filled.Send, contentDescription = null)
                Spacer(Modifier.size(8.dp))
                Text("规划路线到此")
            }
            OutlinedButton(
                onClick = { openInAMap(ctx, station) },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("station_open_in_amap_button"),
            ) {
                Icon(Icons.Filled.Map, contentDescription = null)
                Spacer(Modifier.size(8.dp))
                Text("在高德地图打开")
            }
            Spacer(Modifier.size(8.dp))
        }
    }
}

@Composable
private fun Chip(label: String, icon: ImageVector) {
    Row(
        modifier = Modifier
            .background(
                MaterialTheme.colorScheme.secondaryContainer,
                RoundedCornerShape(50),
            )
            .padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(14.dp))
        Spacer(Modifier.size(4.dp))
        Text(label, style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
private fun InfoRow(icon: ImageVector, label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(18.dp),
        )
        Spacer(Modifier.size(10.dp))
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(value, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

private fun openInAMap(ctx: android.content.Context, station: ChargingStation) {
    val lat = station.latitude
    val lng = station.longitude
    val name = Uri.encode(station.name)
    // amapuri:// schema — Android AMap app. Falls back to https://uri.amap.com
    // when not installed.
    val amapSchema = Uri.parse(
        "amapuri://route/plan/?dlat=$lat&dlon=$lng&dname=$name" +
            "&dev=0&t=0&sourceApplication=Tautomation"
    )
    val webFallback = Uri.parse(
        "https://uri.amap.com/marker?position=$lng,$lat&name=$name&src=tautomation"
    )
    val tryAmap = Intent(Intent.ACTION_VIEW, amapSchema)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    val resolved = ctx.packageManager.resolveActivity(tryAmap, 0)
    val intent = if (resolved != null) tryAmap
        else Intent(Intent.ACTION_VIEW, webFallback).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try { ctx.startActivity(intent) } catch (_: Throwable) {}
}
