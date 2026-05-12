package cloud.teplanner.android.map

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import cloud.teplanner.android.core.network.RoutePlanSummary

/**
 * 最近 tab — list of the user's saved trips. Tap a row to re-plan
 * the same destination via RoutePreview. Mirror of iOS RecentTripsView.
 *
 * Empty state intentionally chatty to point users at the right
 * affordance (search a destination + 发车 to populate history).
 */
@Composable
fun RecentTripsSheet(
    onSelect: (RoutePlanSummary) -> Unit,
    vm: RecentTripsViewModel = hiltViewModel(),
    modifier: Modifier = Modifier,
) {
    val state by vm.state.collectAsState()
    Column(modifier = modifier.testTag("recent_trips_sheet")) {
        when {
            state.isLoading && state.trips.isEmpty() -> Loading()
            state.error != null && state.trips.isEmpty() -> ErrorRow(state.error!!)
            state.trips.isEmpty() -> EmptyState()
            else -> LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(state.trips, key = { it.id }) { trip ->
                    TripRow(
                        trip = trip,
                        onClick = { onSelect(trip) },
                    )
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
private fun TripRow(trip: RoutePlanSummary, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("recent_trip_${trip.id}")
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Filled.History,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(20.dp),
        )
        Spacer(Modifier.size(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                trip.destination.address ?: "(目的地无地址)",
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 1,
            )
            val distance = trip.totalDistanceKm?.let { "${"%.0f".format(it)} km" }
            val duration = trip.totalDurationMinutes?.let { mins ->
                if (mins >= 60) "${mins / 60} 小时 ${mins % 60} 分" else "$mins 分"
            }
            val subtitle = listOfNotNull(distance, duration, trip.createdAt?.take(10))
                .joinToString(" · ")
            if (subtitle.isNotEmpty()) {
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Icon(
            Icons.Filled.PlayCircle,
            contentDescription = "再次规划",
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(22.dp),
        )
    }
}

@Composable
private fun EmptyState() {
    Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(
                Icons.Filled.History,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(40.dp),
            )
            Text(
                "还没有保存的行程",
                style = MaterialTheme.typography.titleSmall,
            )
            Text(
                "在「附近」搜索目的地 → 发车之后，行程会自动出现在这里。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun Loading() {
    Box(modifier = Modifier.fillMaxSize().padding(48.dp), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(modifier = Modifier.size(28.dp))
    }
}

@Composable
private fun ErrorRow(message: String) {
    Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
        Text(
            "加载失败：$message",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
        )
    }
}
