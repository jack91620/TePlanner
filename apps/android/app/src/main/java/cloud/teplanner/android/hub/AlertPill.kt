package cloud.teplanner.android.hub

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cloud.teplanner.android.core.network.VehicleStateResponse

/**
 * Top-of-Hub alert pill — Android port of iOS AlertPillView.
 *
 * Picks the highest-priority active alert from the vehicle snapshot
 * and renders a banner with title + detail + a primary action button
 * (close keeper / disable sentry / lock / acknowledge). Status chips
 * stay on Hub for tactile control; the pill exists to make a single
 * critical issue prominent at the top so users don't miss it.
 *
 * Priority order matches iOS (highest to lowest):
 *   campMode > sentryMode > leftUnlocked > cabinOverheat > chargeComplete
 *
 * Returns Unit / nothing when there's no active alert.
 */
@Composable
fun AlertPill(
    state: VehicleStateResponse?,
    onCloseClimateKeeper: () -> Unit,
    onCloseSentry: () -> Unit,
    onLock: () -> Unit,
) {
    val alert = state?.let(::deriveAlert) ?: return

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceContainerHigh,
                RoundedCornerShape(14.dp),
            )
            .border(
                width = 1.dp,
                color = alert.severityColor.copy(alpha = 0.4f),
                shape = RoundedCornerShape(14.dp),
            )
            .padding(horizontal = 14.dp, vertical = 10.dp)
            .testTag("alert_pill_${alert.kind.id}"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            alert.icon,
            contentDescription = null,
            tint = alert.severityColor,
            modifier = Modifier.size(22.dp),
        )
        Spacer(Modifier.size(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                alert.title,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            )
            Text(
                alert.detail,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
            )
        }
        if (alert.actionLabel != null) {
            val handler: () -> Unit = when (alert.kind) {
                AlertKind.CAMP_MODE,
                AlertKind.PET_MODE,
                AlertKind.CLIMATE_KEEPER -> onCloseClimateKeeper
                AlertKind.SENTRY_MODE -> onCloseSentry
                AlertKind.LEFT_UNLOCKED -> onLock
                AlertKind.CABIN_OVERHEAT,
                AlertKind.CHARGE_COMPLETE -> { -> /* info-only */ }
            }
            TextButton(
                onClick = handler,
                modifier = Modifier
                    .background(alert.severityColor, CircleShape)
                    .testTag("alert_primary_action_${alert.kind.id}"),
            ) {
                Text(
                    alert.actionLabel,
                    color = Color.White,
                    style = MaterialTheme.typography.labelMedium,
                )
            }
        }
    }
}

private enum class AlertKind(val id: String) {
    CAMP_MODE("camp_mode"),
    PET_MODE("pet_mode"),
    CLIMATE_KEEPER("climate_keeper"),
    SENTRY_MODE("sentry_mode"),
    LEFT_UNLOCKED("left_unlocked"),
    CABIN_OVERHEAT("cabin_overheat"),
    CHARGE_COMPLETE("charge_complete"),
}

private data class DerivedAlert(
    val kind: AlertKind,
    val title: String,
    val detail: String,
    val icon: ImageVector,
    val severityColor: Color,
    val actionLabel: String?,
)

private fun deriveAlert(state: VehicleStateResponse): DerivedAlert? {
    val critical = Color(0xFFFB8C00)
    val info = Color(0xFF1976D2)

    // 1. Climate keeper modes — camp / pet / keeper share the same
    //    close-command handler but distinct titles + icons.
    when (state.climateKeeperMode) {
        3 -> return DerivedAlert(
            kind = AlertKind.CAMP_MODE,
            title = "露营模式开启中",
            detail = "电耗较高，建议离开车辆前关闭。",
            icon = Icons.Filled.Bedtime,
            severityColor = critical,
            actionLabel = "关闭",
        )
        2 -> return DerivedAlert(
            kind = AlertKind.PET_MODE,
            title = "宠物模式开启中",
            detail = "仅在乘员仓有宠物时使用。",
            icon = Icons.Filled.Bedtime,
            severityColor = critical,
            actionLabel = "关闭",
        )
        1 -> return DerivedAlert(
            kind = AlertKind.CLIMATE_KEEPER,
            title = "保持空调开启中",
            detail = "持续运行会快速耗电。",
            icon = Icons.Filled.Bedtime,
            severityColor = critical,
            actionLabel = "关闭",
        )
    }

    // 2. Sentry mode
    if (state.sentryMode == true) {
        return DerivedAlert(
            kind = AlertKind.SENTRY_MODE,
            title = "哨兵模式开启中",
            detail = "驻车监控运行中，电耗约 1%/小时。",
            icon = Icons.Filled.Shield,
            severityColor = critical,
            actionLabel = "关闭",
        )
    }

    // 3. Left unlocked while parked
    if (state.locked == false && state.state in setOf("asleep", "parked", "offline", null)) {
        return DerivedAlert(
            kind = AlertKind.LEFT_UNLOCKED,
            title = "车辆未锁",
            detail = "确认无人在车内后请锁好。",
            icon = Icons.Filled.LockOpen,
            severityColor = critical,
            actionLabel = "锁车",
        )
    }

    // 4. Cabin overheat — inside temp ≥ 45°C (matches iOS rule's
    //    default threshold). info severity, no close action.
    val temp = state.insideTemp
    if (temp != null && temp >= 45.0) {
        return DerivedAlert(
            kind = AlertKind.CABIN_OVERHEAT,
            title = "车舱过热",
            detail = "车内温度 ${"%.0f".format(temp)} °C，请勿放置易损物品。",
            icon = Icons.Filled.WbSunny,
            severityColor = critical,
            actionLabel = null,
        )
    }

    // 5. Charge complete — info-only, no auto-dismiss; user manually
    //    unplugs which clears the state.
    if (state.chargingState == "Complete") {
        return DerivedAlert(
            kind = AlertKind.CHARGE_COMPLETE,
            title = "充电完成",
            detail = "可以拔枪了；如果车在公共桩，请尽快移车。",
            icon = Icons.Filled.Bolt,
            severityColor = info,
            actionLabel = null,
        )
    }

    return null
}
