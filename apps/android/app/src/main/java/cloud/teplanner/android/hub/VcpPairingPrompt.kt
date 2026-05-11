package cloud.teplanner.android.hub

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext

/**
 * Mirror of iOS HubView.promptVCPPairingIfNeeded + the
 * "配对车辆控制" alert. Surfaces a one-time dialog the first time
 * the user reaches Hub with a real vehicle in hand. Tap "立即配对"
 * → opens https://tesla.com/_ak/api.teplanner.cloud, which on a
 * phone with Tesla App installed deep-links into the partner-key
 * authorization screen (Tesla's official pairing flow for VCP).
 *
 * Either action flips a SharedPreferences flag so we don't nag
 * again. Users who want to pair later have the same call surfaced
 * via the hub menu (see HubScreen — "配对车辆控制").
 */

private const val VCP_PREFS = "vcp_pairing_prefs"
private const val KEY_PROMPTED = "vcp_pairing_prompted"
const val VCP_PAIRING_URL = "https://tesla.com/_ak/api.teplanner.cloud"

@Composable
fun VcpPairingPrompt(showWhenVehicleKnown: Boolean) {
    val context = LocalContext.current
    val prefs = remember {
        context.getSharedPreferences(VCP_PREFS, Context.MODE_PRIVATE)
    }
    var showing by remember {
        mutableStateOf(
            showWhenVehicleKnown && !prefs.getBoolean(KEY_PROMPTED, false)
        )
    }
    if (!showing) return

    AlertDialog(
        onDismissRequest = {
            prefs.edit().putBoolean(KEY_PROMPTED, true).apply()
            showing = false
        },
        title = { Text("配对车辆控制") },
        text = {
            Text(
                "为了让 Tautomation 能直接调用车辆命令（关闭露营 / 启动空调预热 / 调整充电限额等），" +
                "需要你在 Tesla 官方 App 中授权一次。点击「立即配对」会打开 Tesla App 完成。" +
                "可在右上角菜单 → 配对车辆控制 重新打开。"
            )
        },
        confirmButton = {
            TextButton(onClick = {
                openVcpPairingUrl(context)
                prefs.edit().putBoolean(KEY_PROMPTED, true).apply()
                showing = false
            }) { Text("立即配对") }
        },
        dismissButton = {
            TextButton(onClick = {
                prefs.edit().putBoolean(KEY_PROMPTED, true).apply()
                showing = false
            }) { Text("稍后再说") }
        },
    )
}


fun openVcpPairingUrl(context: Context) {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(VCP_PAIRING_URL))
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(intent)
}
