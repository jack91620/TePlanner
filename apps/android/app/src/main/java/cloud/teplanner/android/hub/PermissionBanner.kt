package cloud.teplanner.android.hub

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver

/**
 * Mirror of iOS PermissionBannerView. Surfaces on Hub when the user
 * denied (or never granted) notification permission — without push,
 * the camp/sentry/cabin/charge-complete alerts never reach them and
 * the product loses its core loop.
 *
 * Behavior:
 *   - First launch on Android 13+ with permission not yet asked:
 *     fire the system prompt automatically (parity with iOS
 *     "notDetermined → request" flow).
 *   - Permission denied + global notifications still off after
 *     dismissal: banner shows. Buttons:
 *       · 去开启 → app notification settings (or system permission
 *         settings if the user previously selected "Don't ask
 *         again", which the runtime can't override).
 *       · 今天先不 → 24h snooze in SharedPreferences.
 *   - Granted (or pre-Android-13 default-on): nothing renders.
 *
 * State is refreshed on each ON_RESUME so returning from system
 * Settings reflects immediately.
 */

private const val PREFS = "permission_banner_prefs"
private const val KEY_HIDE_UNTIL = "notification_hide_until_ms"
private const val KEY_FIRST_PROMPT_FIRED = "notification_first_prompt_fired"
private const val NAG_INTERVAL_MS = 24L * 60 * 60 * 1000

@Composable
fun PermissionBanner() {
    val context = LocalContext.current
    val prefs = remember {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }
    val lifecycleOwner = LocalLifecycleOwner.current

    var status by remember { mutableStateOf(currentStatus(context)) }
    var hideUntilMs by remember {
        mutableStateOf(prefs.getLong(KEY_HIDE_UNTIL, 0L))
    }

    val requestLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) {
        status = currentStatus(context)
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                status = currentStatus(context)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // First-time Android 13+ prompt fire (iOS notDetermined parity).
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        && status == NotifStatus.NotDetermined
        && !prefs.getBoolean(KEY_FIRST_PROMPT_FIRED, false)
    ) {
        prefs.edit().putBoolean(KEY_FIRST_PROMPT_FIRED, true).apply()
        requestLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    val shouldShow = status == NotifStatus.Denied
        && System.currentTimeMillis() >= hideUntilMs
    if (!shouldShow) return

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("permission_banner"),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.5f),
        ),
        shape = RoundedCornerShape(12.dp),
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(Color(0xFFFB8C00), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.NotificationsOff,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(20.dp),
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "通知权限未开启",
                    style = MaterialTheme.typography.titleSmall,
                )
                Text(
                    "没有通知就收不到露营 / 哨兵 / 充电完成等提醒。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(
                    modifier = Modifier.padding(top = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Button(
                        onClick = {
                            // Runtime permission may already be granted but
                            // user globally disabled in Settings — go to app
                            // notification page in that case. Either way the
                            // user lands somewhere they can flip the switch.
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                                && ContextCompat.checkSelfPermission(
                                    context, Manifest.permission.POST_NOTIFICATIONS,
                                ) != PackageManager.PERMISSION_GRANTED
                                && (context as? Activity)?.shouldShowRequestPermissionRationale(
                                    Manifest.permission.POST_NOTIFICATIONS,
                                ) == true
                            ) {
                                requestLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                            } else {
                                openAppNotificationSettings(context)
                            }
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFFFB8C00),
                        ),
                        modifier = Modifier.testTag("permission_open_settings"),
                    ) {
                        Text("去开启")
                    }
                    OutlinedButton(
                        onClick = {
                            val until = System.currentTimeMillis() + NAG_INTERVAL_MS
                            prefs.edit().putLong(KEY_HIDE_UNTIL, until).apply()
                            hideUntilMs = until
                        },
                        modifier = Modifier.testTag("permission_dismiss_today"),
                    ) {
                        Text("今天先不")
                    }
                }
            }
        }
    }
}

private enum class NotifStatus { Granted, Denied, NotDetermined }

private fun currentStatus(context: Context): NotifStatus {
    // Global notification toggle beats per-app runtime permission —
    // user can revoke it on any Android version.
    if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
        return NotifStatus.Denied
    }
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
        return NotifStatus.Granted
    }
    val granted = ContextCompat.checkSelfPermission(
        context, Manifest.permission.POST_NOTIFICATIONS,
    ) == PackageManager.PERMISSION_GRANTED
    if (granted) return NotifStatus.Granted

    val activity = context as? Activity
    // shouldShowRequestPermissionRationale returns true only after a
    // first denial; false either when never asked OR when user picked
    // "Don't ask again" — we can't distinguish those, so we lean on
    // KEY_FIRST_PROMPT_FIRED to know whether the prompt has been
    // dispatched at least once.
    return if (activity != null
        && !activity.shouldShowRequestPermissionRationale(
            Manifest.permission.POST_NOTIFICATIONS,
        )
    ) {
        // Either never prompted, or "don't ask again" — caller checks
        // the first-prompt flag to differentiate.
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_FIRST_PROMPT_FIRED, false)) {
            NotifStatus.Denied
        } else {
            NotifStatus.NotDetermined
        }
    } else {
        NotifStatus.Denied
    }
}

private fun openAppNotificationSettings(context: Context) {
    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
    } else {
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", context.packageName, null))
    }
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(intent)
}
