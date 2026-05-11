package cloud.teplanner.android.auth

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel

/**
 * Tesla OAuth landing screen. Tap "连接 Tesla 账户" → fetch auth URL
 * → present TeslaWebView → handle the embedded JSON callback →
 * navigate to Hub. Mirrors iOS LoginView.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(
    onLoggedIn: () -> Unit,
    vm: LoginViewModel = hiltViewModel(),
) {
    val state by vm.state.collectAsState()

    LaunchedEffect(state) {
        if (state is LoginViewModel.State.Success) onLoggedIn()
    }

    when (val s = state) {
        is LoginViewModel.State.Ready -> Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("登录 Tesla") },
                    navigationIcon = {
                        IconButton(onClick = vm::cancel) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回")
                        }
                    },
                )
            },
        ) { padding ->
            BackHandler(enabled = true) { vm.cancel() }
            Box(modifier = Modifier.padding(padding).fillMaxSize()) {
                TeslaWebView(
                    authUrl = s.authUrl,
                    onCallback = { code, returnedState, body ->
                        vm.handleCallback(code, returnedState, body)
                    },
                    onLoadError = { /* surface in next pass; failures rare */ },
                    modifier = Modifier.fillMaxSize().testTag("tesla_webview"),
                )
            }
        }

        is LoginViewModel.State.ProcessingCallback -> ProgressSplash("正在登录…")

        is LoginViewModel.State.Failed -> Splash(
            isLoading = false,
            errorMessage = s.message,
            onRetry = vm::retry,
            onLogin = vm::start,
        )

        else -> Splash(
            isLoading = state is LoginViewModel.State.LoadingAuthUrl,
            errorMessage = null,
            onRetry = vm::start,
            onLogin = vm::start,
        )
    }
}


@Composable
private fun ProgressSplash(label: String) {
    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            CircularProgressIndicator()
            Spacer(Modifier.height(16.dp))
            Text(label, style = MaterialTheme.typography.bodyMedium)
        }
    }
}


@Composable
private fun Splash(
    isLoading: Boolean,
    errorMessage: String?,
    onRetry: () -> Unit,
    onLogin: () -> Unit,
) {
    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(8.dp))
            Box(
                modifier = Modifier
                    .size(160.dp)
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant,
                        shape = CircleShape,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "T",
                    fontSize = 96.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFFE82127),
                )
            }
            Spacer(Modifier.height(24.dp))
            Text("Tautomation", style = MaterialTheme.typography.headlineLarge)
            Text(
                "你的特斯拉，更懂你",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Spacer(Modifier.height(28.dp))
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Feature(
                    icon = Icons.Filled.NotificationsActive,
                    label = "露营 / 哨兵 / 充电完成自动提醒",
                )
                Feature(
                    icon = Icons.Filled.Bolt,
                    label = "Telemetry 实时车况，秒级响应",
                )
                Feature(
                    icon = Icons.Filled.LocationOn,
                    label = "进出地理围栏触发自动化",
                )
                Feature(
                    icon = Icons.Filled.TouchApp,
                    label = "推送通知一键执行车辆动作",
                )
            }

            Spacer(Modifier.height(32.dp))
            Button(
                onClick = onLogin,
                enabled = !isLoading,
                modifier = Modifier.fillMaxWidth().testTag("login_button"),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (isLoading) {
                        CircularProgressIndicator(
                            modifier = Modifier.height(16.dp).width(16.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onPrimary,
                        )
                        Spacer(Modifier.width(8.dp))
                    }
                    Text("连接 Tesla 账户")
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }

    if (errorMessage != null) {
        AlertDialog(
            onDismissRequest = onRetry,
            title = { Text("登录失败") },
            text = { Text(errorMessage) },
            confirmButton = {
                TextButton(onClick = onRetry) { Text("重试") }
            },
            dismissButton = {
                TextButton(onClick = onRetry) { Text("取消") }
            },
        )
    }
}


@Composable
private fun Feature(icon: ImageVector, label: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(28.dp),
        )
        Text(label, style = MaterialTheme.typography.bodyMedium)
    }
}
