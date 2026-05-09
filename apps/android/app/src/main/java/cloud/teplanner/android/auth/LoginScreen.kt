package cloud.teplanner.android.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

/**
 * Phase F.1 — email + password login. Mirrors iOS [LoginView]'s
 * email path; Tesla OAuth flow ships in a later sub-phase once the
 * Android Tesla mobile app supports the deep link.
 */
@Composable
fun LoginScreen(
    onLoggedIn: () -> Unit,
    auth: AuthSession = hiltViewModel(),
) {
    val state by auth.state.collectAsState()
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var registerMode by remember { mutableStateOf(false) }

    LaunchedEffect(state) {
        if (state is AuthSession.LoginUiState.Success) onLoggedIn()
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Tautomation",
                style = MaterialTheme.typography.headlineLarge,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = if (registerMode) "创建账户" else "登录账户",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(32.dp))

            OutlinedTextField(
                value = email,
                onValueChange = {
                    email = it
                    auth.acknowledgeError()
                },
                label = { Text("邮箱") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = password,
                onValueChange = {
                    password = it
                    auth.acknowledgeError()
                },
                label = { Text("密码") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth(),
            )

            (state as? AuthSession.LoginUiState.Error)?.let { err ->
                Spacer(Modifier.height(12.dp))
                Text(
                    text = err.message,
                    color = Color.Red,
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            Spacer(Modifier.height(20.dp))
            Button(
                onClick = {
                    if (registerMode) {
                        auth.register(email, password, nickname = null)
                    } else {
                        auth.login(email, password)
                    }
                },
                enabled = state !is AuthSession.LoginUiState.Loading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (state is AuthSession.LoginUiState.Loading) {
                        CircularProgressIndicator(
                            modifier = Modifier.height(16.dp).width(16.dp),
                            strokeWidth = 2.dp,
                        )
                        Spacer(Modifier.width(8.dp))
                    }
                    Text(if (registerMode) "注册" else "登录")
                }
            }

            Spacer(Modifier.height(8.dp))
            TextButton(onClick = {
                registerMode = !registerMode
                auth.acknowledgeError()
            }) {
                Text(if (registerMode) "已有账户？登录" else "没有账户？注册")
            }
        }
    }
}
