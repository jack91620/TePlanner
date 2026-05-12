package cloud.teplanner.android.hub.quickactions

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import cloud.teplanner.android.core.network.ShareType
import kotlinx.serialization.json.Json

/**
 * Sheet for redeeming a share code into the user's library.
 * 3-phase: input → preview → imported. Mirrors iOS
 * ImportShareSheet.swift.
 */
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
fun ImportShareSheet(
    onDismiss: () -> Unit,
    viewModel: ShareViewModel = hiltViewModel(),
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val lookupState by viewModel.lookupState.collectAsState()

    var codeInput by remember { mutableStateOf("") }

    ModalBottomSheet(
        onDismissRequest = {
            viewModel.resetLookup()
            onDismiss()
        },
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
                .semantics { testTagsAsResourceId = true },
        ) {
            Text(
                "导入分享码",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(16.dp))
            when (val s = lookupState) {
                is ShareViewModel.LookupState.Idle, is ShareViewModel.LookupState.Looking -> {
                    inputView(
                        codeInput = codeInput,
                        onCodeChange = { codeInput = it.uppercase() },
                        loading = s is ShareViewModel.LookupState.Looking,
                        onContinue = { viewModel.lookupShare(codeInput) },
                    )
                }
                is ShareViewModel.LookupState.Preview -> {
                    previewView(
                        detail = s.detail,
                        onConfirm = { viewModel.importPreviewIntoLibrary() },
                    )
                }
                is ShareViewModel.LookupState.Imported -> {
                    importedView(
                        name = s.name,
                        type = s.type,
                        onDone = {
                            viewModel.resetLookup()
                            onDismiss()
                        },
                    )
                }
                is ShareViewModel.LookupState.Failed -> {
                    Column {
                        inputView(
                            codeInput = codeInput,
                            onCodeChange = { codeInput = it.uppercase() },
                            loading = false,
                            onContinue = { viewModel.lookupShare(codeInput) },
                        )
                        Spacer(Modifier.height(12.dp))
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.testTag("import_share_error"),
                        ) {
                            Icon(
                                Icons.Filled.Warning,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.error,
                                modifier = Modifier.size(18.dp),
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                s.message,
                                color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun inputView(
    codeInput: String,
    onCodeChange: (String) -> Unit,
    loading: Boolean,
    onContinue: () -> Unit,
) {
    Text(
        "输入好友给你的 6 位分享码",
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Spacer(Modifier.height(12.dp))
    OutlinedTextField(
        value = codeInput,
        onValueChange = onCodeChange,
        placeholder = { Text("ABCD-EF") },
        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(
            capitalization = KeyboardCapitalization.Characters,
            autoCorrect = false,
        ),
        textStyle = androidx.compose.ui.text.TextStyle(
            fontSize = 28.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = FontFamily.Monospace,
            textAlign = TextAlign.Center,
        ),
        singleLine = true,
        modifier = Modifier
            .fillMaxWidth()
            .testTag("import_share_code_field"),
    )
    Spacer(Modifier.height(12.dp))
    Button(
        onClick = onContinue,
        enabled = !loading &&
            codeInput.replace("-", "").replace(" ", "").length >= 6,
        modifier = Modifier
            .fillMaxWidth()
            .testTag("import_share_continue_button"),
    ) {
        if (loading) {
            CircularProgressIndicator(
                color = MaterialTheme.colorScheme.onPrimary,
                modifier = Modifier.size(18.dp),
            )
        } else {
            Text("继续")
        }
    }
}

@Composable
private fun previewView(
    detail: cloud.teplanner.android.core.network.ShareDetailResponse,
    onConfirm: () -> Unit,
) {
    val json = remember { Json { ignoreUnknownKeys = true } }
    val payloadText = remember(detail) {
        runCatching {
            json.encodeToString(
                kotlinx.serialization.serializer<Map<String, kotlinx.serialization.json.JsonElement>>(),
                detail.payload,
            )
        }.getOrNull()
    }
    val action: SharedActionPayload? = remember(detail) {
        if (detail.shareType != ShareType.ACTION) null
        else runCatching {
            json.decodeFromString(SharedActionPayload.serializer(), payloadText ?: return@runCatching null)
        }.getOrNull()
    }
    val rule: SharedRulePayload? = remember(detail) {
        if (detail.shareType != ShareType.RULE) null
        else runCatching {
            json.decodeFromString(SharedRulePayload.serializer(), payloadText ?: return@runCatching null)
        }.getOrNull()
    }

    Column(modifier = Modifier
        .fillMaxWidth()
        .testTag(
            if (detail.shareType == ShareType.RULE) "import_share_preview_rule"
            else "import_share_preview_action"
        )) {
        if (rule != null) {
            Text(rule.name, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.Warning,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.tertiary,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    // Mirrors iOS commit f65d1a3: be honest about
                    // post-import disabled state, not the sharer's
                    // enabled state which would mislead the receiver.
                    "导入后默认关闭，需手动开启",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.tertiary,
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                "Spec 字段：${rule.spec.keys.sorted().joinToString(", ")}",
                style = MaterialTheme.typography.bodySmall,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else if (action != null) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    HubIconLibrary.resolve(SemanticIcon.symbolFor(action.icon)),
                    contentDescription = null,
                    modifier = Modifier.size(36.dp),
                )
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(action.name, style = MaterialTheme.typography.titleMedium)
                    Text(
                        "${action.steps.size} 步",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            action.steps.forEachIndexed { idx, step ->
                Row {
                    Text(
                        "${idx + 1}.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        cloud.teplanner.android.automations.RuleDisplay.capabilityName(step.capability),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    val delay = step.delayMsAfter
                    if (delay != null && delay > 0) {
                        Text(
                            " → 等 ${delay / 1000} 秒",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            if (action.confirmRequired) {
                Spacer(Modifier.height(8.dp))
                Row {
                    Icon(
                        Icons.Filled.Warning,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.tertiary,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "执行前需要确认",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.tertiary,
                    )
                }
            }
        } else {
            Text(
                "分享内容无法解析",
                color = MaterialTheme.colorScheme.error,
            )
        }
        Spacer(Modifier.height(20.dp))
        Button(
            onClick = onConfirm,
            modifier = Modifier
                .fillMaxWidth()
                .testTag("import_share_confirm_button"),
        ) {
            Text("加到我的列表")
        }
    }
}

@Composable
private fun importedView(
    name: String,
    type: ShareType,
    onDone: () -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Spacer(Modifier.height(8.dp))
        Icon(
            Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(56.dp),
        )
        Spacer(Modifier.height(12.dp))
        Text(
            "已导入「$name」",
            style = MaterialTheme.typography.titleMedium,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            if (type == ShareType.ACTION)
                "已加到快捷操作动作库（未分配槽位）。"
            else
                "已加到自动化列表（默认关闭，按需开启）。",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(20.dp))
        Button(
            onClick = onDone,
            modifier = Modifier
                .fillMaxWidth()
                .testTag("import_share_close_button"),
        ) {
            Text("完成")
        }
    }
}

