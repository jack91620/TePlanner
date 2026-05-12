package cloud.teplanner.android.hub.quickactions

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessAlarm
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.AirportShuttle
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.BatteryFull
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Campaign
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.EvStation
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.RoomService
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Thermostat
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.material.icons.filled.Work
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Maps iOS SF Symbol names to Material icons for cross-platform
 * round-tripping. Mirrors `apps/ios/.../Models/HubAction.swift`
 * HubActionIconLibrary (the same 32 SF Symbol values, grouped into
 * the same 6 sections).
 *
 * Wire format stores the SF Symbol name (e.g. "lock.fill") so that
 * an action created on iOS and synced via user_settings.hub.actions
 * renders correctly on Android, and vice versa. Android also stores
 * SF Symbol names when creating new actions — `resolve()` does the
 * Material lookup at render time.
 *
 * Unknown / removed SF Symbols fall back to [Icons.Filled.Bolt] —
 * same fallback the iOS app uses (default semantic = "bolt").
 */
object HubIconLibrary {

    data class Group(val label: String, val icons: List<String>)

    val groups: List<Group> = listOf(
        Group("安全", listOf(
            "lock.fill", "lock.open.fill",
            "shield.lefthalf.filled", "light.beacon.max.fill",
            "megaphone.fill",
        )),
        Group("门窗", listOf(
            "door.left.hand.open", "suitcase.fill",
            "car.rear.fill", "rectangle.portrait.and.arrow.right.fill",
            "sun.haze.fill",
        )),
        Group("空调", listOf(
            "thermometer.medium", "snowflake",
            "moon.zzz.fill", "fan.fill",
            "flame.fill",
        )),
        Group("充电", listOf(
            "bolt.fill", "bolt.car.fill",
            "ev.charger", "battery.100",
            "hand.raised.slash.fill",
        )),
        Group("媒体", listOf(
            "play.fill", "pause.fill",
            "speaker.wave.2.fill", "speaker.slash.fill",
            "music.note",
        )),
        Group("其他", listOf(
            "location.fill", "paperplane.fill",
            "hand.tap.fill", "house.fill",
            "sparkles", "star.fill",
            "gearshape.fill",
        )),
    )

    val all: List<String> = groups.flatMap { it.icons }

    private val sfToMaterial: Map<String, ImageVector> = mapOf(
        // Security
        "lock.fill" to Icons.Filled.Lock,
        "lock.open.fill" to Icons.Filled.LockOpen,
        "shield.lefthalf.filled" to Icons.Filled.Shield,
        "light.beacon.max.fill" to Icons.Filled.Campaign,
        "megaphone.fill" to Icons.Filled.Campaign,
        // Doors/windows
        "door.left.hand.open" to Icons.Filled.ExitToApp,
        "suitcase.fill" to Icons.Filled.Work,
        "car.rear.fill" to Icons.Filled.DirectionsCar,
        "rectangle.portrait.and.arrow.right.fill" to Icons.Filled.ExitToApp,
        "sun.haze.fill" to Icons.Filled.WbSunny,
        // Climate
        "thermometer.medium" to Icons.Filled.Thermostat,
        "snowflake" to Icons.Filled.AcUnit,
        "moon.zzz.fill" to Icons.Filled.Bedtime,
        "fan.fill" to Icons.Filled.Whatshot,
        "flame.fill" to Icons.Filled.LocalFireDepartment,
        // Charging
        "bolt.fill" to Icons.Filled.Bolt,
        "bolt.car.fill" to Icons.Filled.Bolt,
        "ev.charger" to Icons.Filled.EvStation,
        "battery.100" to Icons.Filled.BatteryFull,
        "hand.raised.slash.fill" to Icons.Filled.VolumeOff,
        // Media
        "play.fill" to Icons.Filled.PlayArrow,
        "pause.fill" to Icons.Filled.Pause,
        "speaker.wave.2.fill" to Icons.Filled.VolumeUp,
        "speaker.slash.fill" to Icons.Filled.VolumeOff,
        "music.note" to Icons.Filled.MusicNote,
        // Other
        "location.fill" to Icons.Filled.RoomService,
        "paperplane.fill" to Icons.Filled.Send,
        "hand.tap.fill" to Icons.Filled.TouchApp,
        "house.fill" to Icons.Filled.Home,
        "sparkles" to Icons.Filled.AutoAwesome,
        "star.fill" to Icons.Filled.Star,
        "gearshape.fill" to Icons.Filled.Build,
    )

    fun resolve(sfSymbol: String): ImageVector =
        sfToMaterial[sfSymbol] ?: Icons.Filled.Bolt

    fun contains(sfSymbol: String): Boolean = sfSymbol in sfToMaterial.keys
}
