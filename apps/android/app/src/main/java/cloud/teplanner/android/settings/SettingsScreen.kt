package cloud.teplanner.android.settings

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.SortByAlpha

import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import cloud.teplanner.android.BuildConfig
import cloud.teplanner.android.R
import cloud.teplanner.android.util.FeatureFlags
import androidx.compose.material3.Switch
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.AutomationsApi
import cloud.teplanner.android.core.network.ReorderRequest
import javax.inject.Inject

/**
 * Tautomation 设置页 — port of iOS SettingsView.
 *
 * Sections (mirrored from iOS):
 *   通知 — push permission status + system shortcut + 测试通知
 *   自动化 — 活动 (触发记录) + 重置自定义排序
 *   关于 — 版本 + 后端服务状态 link
 *
 * Reached via Hub menu → 设置. Cross-platform Maestro path:
 *   Hub menu → 设置 → 活动 → RecentFires
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    onActivity: () -> Unit,
    vm: SettingsViewModel = hiltViewModel(),
) {
    val ctx = LocalContext.current
    val resetState by vm.resetState.collectAsState()
    var pushStatus by remember { mutableStateOf(currentPushStatus(ctx)) }
    var showResetConfirm by remember { mutableStateOf(false) }
    var showResetResult by remember { mutableStateOf(false) }

    // Re-check on every recomposition triggered by lifecycle resume.
    // SettingsScreen is short-lived so a manual refresh on click is
    // enough; users who toggle the system setting come back and the
    // composable recomposes.
    LaunchedEffect(Unit) {
        pushStatus = currentPushStatus(ctx)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("设置") },
                navigationIcon = {
                    IconButton(
                        onClick = onBack,
                        modifier = Modifier.testTag("settings_back"),
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "返回")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .testTag("settings_view"),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SectionLabel("通知")
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            ) {
                Column(modifier = Modifier.padding(vertical = 4.dp)) {
                    PushStatusRow(status = pushStatus)
                    HorizontalDivider()
                    ActionRow(
                        icon = Icons.AutoMirrored.Filled.OpenInNew,
                        label = "系统通知设置",
                        testTag = "settings_open_system_notifications",
                        onClick = {
                            openSystemNotificationSettings(ctx)
                            pushStatus = currentPushStatus(ctx)
                        },
                    )
                    HorizontalDivider()
                    ActionRow(
                        icon = Icons.AutoMirrored.Filled.Send,
                        label = "发送测试通知",
                        testTag = "settings_send_test_notification",
                        onClick = { fireTestNotification(ctx) },
                    )
                }
            }
            Text(
                "Tautomation 通过系统通知中心推送自动化提醒。可在系统设置里调整声音、" +
                    "横幅样式等。「发送测试通知」会立即弹出一条样例消息——前台或锁屏" +
                    "都能验证。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Spacer(Modifier.height(4.dp))
            SectionLabel("自动化")
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            ) {
                Column(modifier = Modifier.padding(vertical = 4.dp)) {
                    ActionRow(
                        icon = Icons.Filled.History,
                        label = "活动 (触发记录)",
                        testTag = "settings_activity_entry",
                        onClick = onActivity,
                    )
                    HorizontalDivider()
                    ActionRow(
                        icon = Icons.Filled.SortByAlpha,
                        label = "重置自定义排序",
                        testTag = "settings_reset_order_entry",
                        onClick = { showResetConfirm = true },
                    )
                }
            }
            Text(
                "活动 — 查看最近的规则触发推送时间线。\n重置自定义排序 — " +
                    "将自动化列表恢复为默认顺序。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            if (FeatureFlags.isInternalBuild()) {
                Spacer(Modifier.height(4.dp))
                SectionLabel("功能开关 (内部测试)")
                FeatureFlagsCard()
                Text(
                    "仅 Debug / 内部测试版本可见。修改后请回到 Hub 查看效果，部分变化" +
                        "需要重新进入页面才能生效。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(Modifier.height(4.dp))
            SectionLabel("关于")
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            ) {
                Column(modifier = Modifier.padding(vertical = 4.dp)) {
                    InfoRow(
                        label = "版本",
                        value = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
                        testTag = "settings_version",
                    )
                    HorizontalDivider()
                    InfoRow(
                        label = "构建",
                        value = "Tautomation Android",
                    )
                    HorizontalDivider()
                    ActionRow(
                        icon = Icons.Filled.Cloud,
                        label = "后端服务状态",
                        testTag = "settings_backend_status",
                        onClick = {
                            val intent = Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://api.teplanner.cloud"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            try { ctx.startActivity(intent) } catch (_: Throwable) {}
                        },
                    )
                }
            }
            Text(
                "升级 App 不会丢失自动化规则、出行计划、充电限额等设置。规则数据存于" +
                    "后端，与 Tesla 账户绑定；本地偏好（VCP 配对状态、自定义排序等）" +
                    "保存在设备 DataStore 里，重新安装才会清空。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }

    if (showResetConfirm) {
        AlertDialog(
            onDismissRequest = { showResetConfirm = false },
            title = { Text("重置自定义排序？") },
            text = {
                Text("规则将按预设默认顺序展示，自定义拖动顺序会丢失。")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showResetConfirm = false
                        vm.resetOrder()
                        showResetResult = true
                    },
                    modifier = Modifier.testTag("settings_reset_order_confirm"),
                ) { Text("重置", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showResetConfirm = false }) { Text("取消") }
            },
        )
    }

    if (showResetResult) {
        val text = when (val s = resetState) {
            SettingsViewModel.ResetState.Idle -> null
            SettingsViewModel.ResetState.InProgress -> "正在重置…"
            SettingsViewModel.ResetState.Done -> "已重置。返回自动化列表查看默认顺序。"
            is SettingsViewModel.ResetState.Failed -> "重置失败：${s.message}"
        }
        if (text != null && resetState != SettingsViewModel.ResetState.InProgress) {
            AlertDialog(
                onDismissRequest = {
                    showResetResult = false
                    vm.acknowledge()
                },
                title = { Text(if (resetState is SettingsViewModel.ResetState.Done) "完成" else "结果") },
                text = { Text(text) },
                confirmButton = {
                    TextButton(onClick = {
                        showResetResult = false
                        vm.acknowledge()
                    }) { Text("好") }
                },
            )
        }
    }
}

/**
 * Internal-only feature-flag toggles. Mirrors iOS
 * FeatureFlagsSection. Each toggle reads/writes SharedPreferences via
 * FeatureFlags.setOverride; flipping a flag updates the local state
 * immediately and the UI section consumer (e.g. HubScreen) re-reads
 * on next recomposition.
 */
@Composable
private fun FeatureFlagsCard() {
    val ctx = LocalContext.current
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(modifier = Modifier.padding(vertical = 4.dp)) {
            FeatureFlags.Flag.all().forEachIndexed { idx, flag ->
                // Local mutable mirror so the Switch responds without
                // forcing a full Composition tree reload.
                var on by remember(flag.key) { mutableStateOf(FeatureFlags.isOn(ctx, flag)) }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("feature_flag_${flag.key}")
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(flag.displayName, style = MaterialTheme.typography.bodyLarge)
                        Text(
                            flag.description,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Switch(
                        checked = on,
                        onCheckedChange = { newValue ->
                            on = newValue
                            FeatureFlags.setOverride(ctx, flag, newValue)
                        },
                    )
                }
                if (idx < FeatureFlags.Flag.all().lastIndex) HorizontalDivider()
            }
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 4.dp),
    )
}

@Composable
private fun PushStatusRow(status: PushStatus) {
    val (icon, color, label) = when (status) {
        PushStatus.Authorized -> Triple(
            Icons.Filled.CheckCircle, Color(0xFF388E3C), "已开启"
        )
        PushStatus.Denied -> Triple(
            Icons.Filled.Cancel, MaterialTheme.colorScheme.error, "已禁止"
        )
        PushStatus.NotDetermined -> Triple(
            Icons.AutoMirrored.Filled.HelpOutline, Color(0xFFFB8C00), "未询问"
        )
        PushStatus.Unknown -> Triple(
            Icons.Filled.WarningAmber, MaterialTheme.colorScheme.onSurfaceVariant, "—"
        )
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .testTag("settings_push_status"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(20.dp))
        Spacer(Modifier.size(12.dp))
        Text("推送权限", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = color,
            modifier = Modifier.testTag("settings_push_status_label"),
        )
    }
}

@Composable
private fun ActionRow(
    icon: ImageVector,
    label: String,
    testTag: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .testTag(testTag)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(20.dp),
        )
        Spacer(Modifier.size(12.dp))
        Text(label, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        Icon(
            Icons.AutoMirrored.Filled.OpenInNew,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(16.dp),
        )
    }
}

@Composable
private fun InfoRow(label: String, value: String, testTag: String? = null) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .then(testTag?.let { Modifier.testTag(it) } ?: Modifier),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private enum class PushStatus { Authorized, Denied, NotDetermined, Unknown }

private fun currentPushStatus(ctx: Context): PushStatus {
    if (!NotificationManagerCompat.from(ctx).areNotificationsEnabled()) {
        return PushStatus.Denied
    }
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
        return PushStatus.Authorized
    }
    val granted = ContextCompat.checkSelfPermission(
        ctx, Manifest.permission.POST_NOTIFICATIONS,
    ) == PackageManager.PERMISSION_GRANTED
    return if (granted) PushStatus.Authorized else PushStatus.NotDetermined
}

private fun openSystemNotificationSettings(ctx: Context) {
    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
    } else {
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", ctx.packageName, null))
    }
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try { ctx.startActivity(intent) } catch (_: Throwable) {}
}

private const val DIAGNOSTIC_CHANNEL_ID = "diagnostic"
private const val DIAGNOSTIC_NOTIFICATION_ID = 9001

private fun fireTestNotification(ctx: Context) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (mgr.getNotificationChannel(DIAGNOSTIC_CHANNEL_ID) == null) {
            mgr.createNotificationChannel(
                NotificationChannel(
                    DIAGNOSTIC_CHANNEL_ID,
                    "诊断测试",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "由设置页「发送测试通知」触发的诊断通知。"
                },
            )
        }
    }
    val n = NotificationCompat.Builder(ctx, DIAGNOSTIC_CHANNEL_ID)
        .setSmallIcon(R.mipmap.ic_launcher)
        .setContentTitle("Tautomation 测试通知")
        .setContentText("如果你看到这条，推送通知工作正常。")
        .setAutoCancel(true)
        .build()
    try {
        NotificationManagerCompat.from(ctx).notify(DIAGNOSTIC_NOTIFICATION_ID, n)
    } catch (_: SecurityException) {
        // POST_NOTIFICATIONS denied; PushStatusRow already shows the state.
    }
}

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val automationsApi: AutomationsApi,
) : ViewModel() {

    sealed class ResetState {
        data object Idle : ResetState()
        data object InProgress : ResetState()
        data object Done : ResetState()
        data class Failed(val message: String) : ResetState()
    }

    private val _resetState = MutableStateFlow<ResetState>(ResetState.Idle)
    val resetState: StateFlow<ResetState> = _resetState.asStateFlow()

    fun resetOrder() {
        if (_resetState.value == ResetState.InProgress) return
        _resetState.value = ResetState.InProgress
        viewModelScope.launch {
            _resetState.value = try {
                automationsApi.reorder(ReorderRequest(ruleIds = emptyList(), clear = true))
                ResetState.Done
            } catch (t: Throwable) {
                ResetState.Failed(t.localizedMessage ?: "未知错误")
            }
        }
    }

    fun acknowledge() {
        _resetState.value = ResetState.Idle
    }
}
