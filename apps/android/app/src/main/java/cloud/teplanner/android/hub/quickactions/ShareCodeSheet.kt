package cloud.teplanner.android.hub.quickactions

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.IntentCompat
import java.text.DateFormat
import java.util.Locale
import java.util.TimeZone

/**
 * Modal shown after a share code is minted. Mirrors iOS
 * ShareCodeSheet — large monospace code + system share intent +
 * copy-to-clipboard. testTag values match iOS exactly so
 * cross_platform Maestro flows reuse the same selectors.
 */
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
fun ShareCodeSheet(
    code: String,
    expiresAt: String,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val clipboard = LocalClipboardManager.current
    val context = LocalContext.current

    val formattedCode = remember(code) {
        if (code.length == 6) "${code.substring(0, 4)}-${code.substring(4)}" else code
    }
    val expiryText = remember(expiresAt) {
        runCatching {
            val iso = java.time.OffsetDateTime.parse(expiresAt)
            val df = DateFormat.getDateTimeInstance(
                DateFormat.MEDIUM, DateFormat.SHORT,
                Locale.SIMPLIFIED_CHINESE,
            )
            df.timeZone = TimeZone.getDefault()
            df.format(java.util.Date.from(iso.toInstant()))
        }.getOrElse { expiresAt }
    }
    val shareMessage = "Tautomation 分享码: $formattedCode\n打开 App → 导入分享码，${expiryText} 前有效。"

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp)
                .semantics { testTagsAsResourceId = true },
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                "分享成功",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(20.dp))
            Text(
                formattedCode,
                fontSize = 44.sp,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f))
                    .padding(horizontal = 28.dp, vertical = 20.dp)
                    .testTag("share_code_text"),
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "有效期至 $expiryText",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(24.dp))
            Button(
                onClick = {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, shareMessage)
                    }
                    context.startActivity(Intent.createChooser(intent, "发送给好友"))
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("share_code_send_button"),
            ) {
                Icon(Icons.Filled.Share, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("发送给好友")
            }
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = {
                    clipboard.setText(AnnotatedString(formattedCode))
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("share_code_copy_button"),
            ) {
                Icon(Icons.Filled.ContentCopy, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("复制分享码")
            }
            Spacer(Modifier.height(8.dp))
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.testTag("share_code_done_button"),
            ) { Text("完成") }
            Spacer(Modifier.height(16.dp))
            Text(
                "好友需要在自己的 App 里点「导入分享码」才能加到他们的列表。\n这个码不绑定车辆 —— 只是把动作的定义传过去。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun remember(key: Any, calc: () -> String): String =
    androidx.compose.runtime.remember(key) { calc() }

