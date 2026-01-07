package com.teplanner.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.teplanner.R
import com.teplanner.data.model.ChargingStation
import com.teplanner.ui.theme.*

@Composable
fun ChargingStationItem(
    station: ChargingStation,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Station Icon
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(TeslaRed.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                painter = painterResource(id = R.drawable.ic_lightning),
                contentDescription = null,
                tint = TeslaRed,
                modifier = Modifier.size(24.dp)
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Station Info
        Column(
            modifier = Modifier.weight(1f)
        ) {
            Text(
                text = station.name,
                color = TextPrimary,
                fontSize = 16.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = station.address ?: "",
                color = TextHint,
                fontSize = 13.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(4.dp))

            // Status row
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Available stalls
                station.availableStalls?.let { available ->
                    station.totalStalls?.let { total ->
                        Text(
                            text = "$available/$total",
                            color = if (available > 0) StatusConnected else StatusError,
                            fontSize = 13.sp
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                    }
                }

                // Power
                station.powerKw?.let { power ->
                    Text(
                        text = "${power}kW",
                        color = TextSecondary,
                        fontSize = 13.sp
                    )
                }
            }
        }

        // Distance
        Column(
            horizontalAlignment = Alignment.End
        ) {
            Text(
                text = formatDistance(station.distanceKm),
                color = TextSecondary,
                fontSize = 14.sp
            )
        }
    }
}

@Composable
fun RecentTripItem(
    name: String,
    address: String?,
    distanceKm: Double,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Info
        Column(
            modifier = Modifier.weight(1f)
        ) {
            Text(
                text = name,
                color = TextPrimary,
                fontSize = 16.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            address?.let {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = it,
                    color = TextHint,
                    fontSize = 13.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        // Distance
        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                painter = painterResource(id = R.drawable.ic_location),
                contentDescription = null,
                tint = TextSecondary,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = formatDistance(distanceKm),
                color = TextSecondary,
                fontSize = 12.sp
            )
        }
    }
}

private fun formatDistance(distanceKm: Double?): String {
    return when {
        distanceKm == null -> "--"
        distanceKm < 1 -> "${(distanceKm * 1000).toInt()} m"
        else -> String.format("%.1f km", distanceKm)
    }
}
