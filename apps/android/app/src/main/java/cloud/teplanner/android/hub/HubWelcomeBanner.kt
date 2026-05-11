package cloud.teplanner.android.hub

import android.content.Context
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

/**
 * First-launch welcome card — explains what Tautomation does in
 * one paragraph + three feature chips. Mirrors iOS HubWelcomeBanner.
 *
 * Persists dismissal in SharedPreferences. Wrapped composable
 * (HubWelcomeBannerHosted) handles the "show until dismissed"
 * lifecycle so HubScreen just drops it in.
 */

private const val WELCOME_PREFS = "hub_welcome_prefs"
private const val KEY_DISMISSED = "welcome_dismissed"

@Composable
fun HubWelcomeBannerHosted() {
    val context = LocalContext.current
    val prefs = remember {
        context.getSharedPreferences(WELCOME_PREFS, Context.MODE_PRIVATE)
    }
    var visible by remember {
        mutableStateOf(!prefs.getBoolean(KEY_DISMISSED, false))
    }
    if (!visible) return
    HubWelcomeBanner(onDismiss = {
        prefs.edit().putBoolean(KEY_DISMISSED, true).apply()
        visible = false
    })
}

@Composable
private fun HubWelcomeBanner(onDismiss: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("hub_welcome_banner")
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.25f),
                shape = RoundedCornerShape(14.dp),
            ),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
        shape = RoundedCornerShape(14.dp),
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.AutoAwesome,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(22.dp),
                )
                Text(
                    "欢迎使用 Tautomation",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier
                        .padding(start = 10.dp)
                        .weight(1f),
                )
                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier.testTag("welcome_banner_dismiss"),
                ) {
                    Icon(
                        Icons.Filled.Close,
                        contentDescription = "关闭",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Text(
                "已为你预设 8 条常用自动化提醒——露营超时、忘锁车、充电完成等。在「自动化」中可逐条查看、调整或新增。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                FeatureChip(Icons.Filled.Bolt, "Telemetry 实时车况")
                FeatureChip(Icons.Filled.LocationOn, "地理围栏")
                FeatureChip(Icons.Filled.TouchApp, "一键执行")
            }
        }
    }
}

@Composable
private fun FeatureChip(icon: ImageVector, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(14.dp),
        )
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 4.dp),
        )
    }
}
