package cloud.teplanner.android.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.AuthApi
import cloud.teplanner.android.core.network.EmailLoginRequest
import cloud.teplanner.android.core.network.EmailRegisterRequest
import cloud.teplanner.android.core.network.TokenStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Phase F.1 — single source of truth for "am I logged in?".
 * Mirrors iOS [AuthSession]: holds the persisted token + user_id,
 * exposes a Compose-observable [state], and routes login / logout
 * actions through the backend.
 *
 * Login is `Idle → Loading → Success | Error`; the consumer
 * (LoginScreen) is responsible for navigating away on Success.
 * Splash decides between Login / Hub by reading [isAuthenticated]
 * synchronously at startup.
 */
@HiltViewModel
class AuthSession @Inject constructor(
    private val authApi: AuthApi,
    private val tokenStore: TokenStore,
) : ViewModel() {

    sealed interface LoginUiState {
        data object Idle : LoginUiState
        data object Loading : LoginUiState
        data object Success : LoginUiState
        data class Error(val message: String) : LoginUiState
    }

    data class Account(val userId: Long, val email: String, val nickname: String?)

    private val _state = MutableStateFlow<LoginUiState>(LoginUiState.Idle)
    val state: StateFlow<LoginUiState> = _state.asStateFlow()

    private val _account = MutableStateFlow(currentAccount())
    val account: StateFlow<Account?> = _account.asStateFlow()

    val isAuthenticated: Boolean
        get() = tokenStore.accessToken != null

    fun login(email: String, password: String) {
        if (_state.value is LoginUiState.Loading) return
        if (email.isBlank() || password.isBlank()) {
            _state.value = LoginUiState.Error("请输入邮箱与密码")
            return
        }
        _state.value = LoginUiState.Loading
        viewModelScope.launch {
            runCatching {
                authApi.login(EmailLoginRequest(email = email.trim(), password = password))
            }.fold(
                onSuccess = { resp ->
                    tokenStore.save(resp.accessToken, resp.userId, resp.email)
                    _account.value = Account(resp.userId, resp.email, resp.nickname)
                    _state.value = LoginUiState.Success
                },
                onFailure = { err ->
                    _state.value = LoginUiState.Error(
                        err.localizedMessage?.takeIf { it.isNotBlank() }
                            ?: "登录失败，请检查网络与账户密码"
                    )
                },
            )
        }
    }

    fun register(email: String, password: String, nickname: String?) {
        if (_state.value is LoginUiState.Loading) return
        if (email.isBlank() || password.isBlank()) {
            _state.value = LoginUiState.Error("请输入邮箱与密码")
            return
        }
        _state.value = LoginUiState.Loading
        viewModelScope.launch {
            runCatching {
                authApi.register(EmailRegisterRequest(email.trim(), password, nickname))
            }.fold(
                onSuccess = { resp ->
                    tokenStore.save(resp.accessToken, resp.userId, resp.email)
                    _account.value = Account(resp.userId, resp.email, resp.nickname)
                    _state.value = LoginUiState.Success
                },
                onFailure = { err ->
                    _state.value = LoginUiState.Error(
                        err.localizedMessage?.takeIf { it.isNotBlank() }
                            ?: "注册失败，请稍后重试"
                    )
                },
            )
        }
    }

    fun logout() {
        tokenStore.clear()
        _account.value = null
        _state.value = LoginUiState.Idle
    }

    /** Reset error state to Idle so retrying doesn't keep the red banner. */
    fun acknowledgeError() {
        if (_state.value is LoginUiState.Error) {
            _state.value = LoginUiState.Idle
        }
    }

    private fun currentAccount(): Account? {
        val id = tokenStore.userId ?: return null
        val email = tokenStore.email ?: return null
        return Account(id, email, null)
    }
}
