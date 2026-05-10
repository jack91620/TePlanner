package cloud.teplanner.android.map

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import cloud.teplanner.android.core.network.ChargingStation

/**
 * Phase F.3.2 — bottom sheet content. Filter chips at the top,
 * scrollable list below. Tap row → caller's onSelect (currently
 * just centers map; F.3.3 wires this to route preview).
 */
@Composable
fun NearbyChargersSheet(
    state: NearbyChargersViewModel.State,
    onFilterChange: (NearbyChargersViewModel.Filter) -> Unit,
    onSelect: (ChargingStation) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        // Filter chips
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            NearbyChargersViewModel.Filter.values().forEach { f ->
                FilterChip(
                    selected = state.filter == f,
                    onClick = { onFilterChange(f) },
                    label = { Text(f.label, style = MaterialTheme.typography.bodySmall) },
                )
            }
        }
        HorizontalDivider()
        when {
            state.isLoading -> Row(
                modifier = Modifier.fillMaxWidth().padding(20.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                Spacer(Modifier.size(8.dp))
                Text("加载中…", style = MaterialTheme.typography.bodyMedium)
            }
            state.error != null -> Text(
                state.error,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(20.dp),
                style = MaterialTheme.typography.bodyMedium,
            )
            state.stations.isEmpty() -> Text(
                "附近暂无充电站\n（如果后端未配置 AMAP_WEB_API_KEY，搜索结果为空）",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(20.dp),
                style = MaterialTheme.typography.bodyMedium,
            )
            else -> LazyColumn(
                contentPadding = PaddingValues(vertical = 4.dp),
            ) {
                items(state.stations, key = { it.id }) { st ->
                    StationRow(station = st, onClick = { onSelect(st) })
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
private fun StationRow(station: ChargingStation, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                station.name,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.weight(1f),
                maxLines = 1,
            )
            station.distanceKm?.let { km ->
                Text(
                    "${"%.1f".format(km)} km",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
        Text(
            station.address,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 2,
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            station.operator?.let { TagChip(it) }
            station.powerKw?.let { TagChip("${it} kW") }
            if (station.availablePorts != null && station.totalPorts != null) {
                TagChip("${station.availablePorts}/${station.totalPorts} 桩")
            }
        }
    }
}

@Composable
private fun TagChip(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSecondaryContainer,
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    )
}
