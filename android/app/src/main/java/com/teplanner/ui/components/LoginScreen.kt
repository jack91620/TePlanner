package com.teplanner.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.teplanner.R
import com.teplanner.ui.theme.*

data class FeatureItem(
    val iconRes: Int,
    val text: String
)

@Composable
fun LoginScreen(
    onConnectTesla: () -> Unit,
    modifier: Modifier = Modifier
) {
    val features = listOf(
        FeatureItem(R.drawable.ic_location, "Get real-time vehicle location"),
        FeatureItem(R.drawable.ic_lightning, "Read current battery level"),
        FeatureItem(R.drawable.ic_route, "Smart charging route planning"),
        FeatureItem(R.drawable.ic_destination_marker, "Send navigation to vehicle")
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        DarkSurface,
                        DarkBackground
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = 320.dp)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Logo Placeholder
            Box(
                modifier = Modifier
                    .size(60.dp)
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(TeslaRed, TeslaRed.copy(alpha = 0.8f))
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "T",
                    color = TextPrimary,
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Title
            Text(
                text = "TePlanner",
                color = TextPrimary,
                fontSize = 24.sp,
                fontWeight = FontWeight.SemiBold
            )

            Spacer(modifier = Modifier.height(6.dp))

            // Subtitle
            Text(
                text = "Tesla Smart Charging Route Planner",
                color = TextSecondary,
                fontSize = 14.sp
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Features List
            Column(
                modifier = Modifier.fillMaxWidth()
            ) {
                features.forEach { feature ->
                    FeatureRow(
                        iconRes = feature.iconRes,
                        text = feature.text
                    )
                }
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Connect Button
            Button(
                onClick = onConnectTesla,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(6.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = TeslaBlue
                )
            ) {
                Text(
                    text = "Connect Tesla Account",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Hint
            Text(
                text = "Connect to unlock full features",
                color = TextTertiary,
                fontSize = 12.sp
            )
        }
    }
}

@Composable
private fun FeatureRow(
    iconRes: Int,
    text: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            painter = painterResource(id = iconRes),
            contentDescription = null,
            tint = TextSecondary,
            modifier = Modifier.size(22.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = text,
            color = TextSecondary.copy(alpha = 0.8f),
            fontSize = 15.sp
        )
    }
    Divider(
        color = DividerColor,
        thickness = 1.dp
    )
}

@Composable
fun LoadingScreen(
    message: String = "Connecting...",
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(DarkBackground),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(32.dp),
                color = TeslaBlue,
                strokeWidth = 3.dp
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = message,
                color = TextSecondary,
                fontSize = 14.sp
            )
        }
    }
}
