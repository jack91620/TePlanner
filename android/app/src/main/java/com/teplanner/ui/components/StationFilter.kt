package com.teplanner.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.teplanner.ui.theme.DarkSurfaceVariant
import com.teplanner.ui.theme.TeslaBlue
import com.teplanner.ui.theme.TextHint
import com.teplanner.ui.theme.TextPrimary

enum class StationFilterType {
    SUPERCHARGER,
    DESTINATION,
    SERVICE
}

@Composable
fun StationFilter(
    activeFilter: StationFilterType,
    onFilterChange: (StationFilterType) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(bottom = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        FilterChip(
            text = "超级充电站",
            isSelected = activeFilter == StationFilterType.SUPERCHARGER,
            onClick = { onFilterChange(StationFilterType.SUPERCHARGER) }
        )
        FilterChip(
            text = "目的地充电",
            isSelected = activeFilter == StationFilterType.DESTINATION,
            onClick = { onFilterChange(StationFilterType.DESTINATION) }
        )
        FilterChip(
            text = "服务中心",
            isSelected = activeFilter == StationFilterType.SERVICE,
            onClick = { onFilterChange(StationFilterType.SERVICE) }
        )
    }
}

@Composable
private fun FilterChip(
    text: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(if (isSelected) TeslaBlue else DarkSurfaceVariant)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = if (isSelected) TextPrimary else TextHint,
            fontSize = 14.sp
        )
    }
}
