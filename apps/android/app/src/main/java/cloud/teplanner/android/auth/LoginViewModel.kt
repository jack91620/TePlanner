package cloud.teplanner.android.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.AuthApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import javax.inject.Inject

/**
 * Drives the Tesla OAuth flow:
 *   1. Fetch auth URL + CSRF state from backend (/auth/tesla/authorize).
 *   2. Hand the URL to TeslaWebView and remember the expected state.
 *   3. When the WebView captures a callback URL with code + state and
 *      extracts the JSON the backend embedded in the auth-data div,
 *      handleCallback() verifies state and stores the token.
 *
 * Direct port of iOS LoginViewModel.swift. Same state-machine,
 * same JSON parser, same CSRF rule — keep behavioral parity.
 */
@HiltViewModel
class LoginViewModel @Inject constructor(
    private val authApi: AuthApi,
    private val authRepository: AuthRepository,
) : ViewModel() {

    sealed interface State {
        data object Idle : State
        data object LoadingAuthUrl : State
        data class Ready(val authUrl: String, val expectedState: String) : State
        data object ProcessingCallback : State
        data object Success : State
        data class Failed(val message: String) : State
    }

    private val _state = MutableStateFlow<State>(State.Idle)
    val state: StateFlow<State> = _state.asStateFlow()

    private var expectedState: String? = null
    private var preliminaryUserId: Long? = null
    private var callbackProcessed = false

    fun start() {
        _state.value = State.LoadingAuthUrl
        callbackProcessed = false

        viewModelScope.launch {
            runCatching {
                authApi.authorizeTesla(userId = authRepository.account.value?.userId)
            }.fold(
                onSuccess = { resp ->
                    expectedState = resp.state
                    preliminaryUserId = resp.userId
                    _state.value = State.Ready(resp.url, resp.state)
                },
                onFailure = { err ->
                    _state.value = State.Failed(
                        err.localizedMessage?.takeIf { it.isNotBlank() }
                            ?: "无法连接服务器，请检查网络后重试"
                    )
                },
            )
        }
    }

    fun handleCallback(code: String, returnedState: String, pageContent: String?) {
        if (callbackProcessed) return
        val expected = expectedState
        if (expected == null) {
            _state.value = State.Failed("状态校验失败，请重新登录")
            return
        }
        if (returnedState != expected) {
            _state.value = State.Failed("安全验证失败，请重试")
            return
        }
        callbackProcessed = true
        _state.value = State.ProcessingCallback

        val parsed = parseCallback(pageContent)
        val token = parsed?.token
        if (token.isNullOrBlank()) {
            _state.value = State.Failed("未能从登录回调中提取凭证")
            return
        }
        val resolvedUserId = parsed.userId ?: preliminaryUserId
        if (resolvedUserId == null) {
            _state.value = State.Failed("未能识别用户ID")
            return
        }

        authRepository.login(
            token = token,
            userId = resolvedUserId,
            email = null,
            nickname = null,
        )
        _state.value = State.Success
    }

    /** Bail-out path the WebView 取消 button calls. */
    fun cancel() {
        callbackProcessed = false
        _state.value = State.Idle
    }

    fun retry() {
        callbackProcessed = false
        start()
    }

    data class ParsedCallback(
        val token: String?,
        val refreshToken: String?,
        val userId: Long?,
    )

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    internal fun parseCallback(pageContent: String?): ParsedCallback? {
        val raw = pageContent?.trim().orEmpty()
        if (raw.isEmpty()) return null
        var jsonString = raw
        if (jsonString.contains("\\\"")) {
            jsonString = jsonString
                .replace("\\\"", "\"")
                .replace("\\\\", "\\")
        }
        if (!jsonString.startsWith("{")) return null

        val obj: JsonObject = runCatching {
            json.parseToJsonElement(jsonString).let { it as? JsonObject }
        }.getOrNull() ?: return null

        val token = stringField(obj, "token")
            ?: stringField(obj, "access_token")
            ?: stringField(obj, "auth_token")
        val refresh = stringField(obj, "refresh_token")

        val userIdEl: JsonElement? = obj["user_id"]
        val userId = userIdEl?.let { el ->
            runCatching { el.jsonPrimitive.content.toLong() }.getOrNull()
        }

        return ParsedCallback(token = token, refreshToken = refresh, userId = userId)
    }

    private fun stringField(obj: JsonObject, key: String): String? {
        return obj[key]?.let { el ->
            runCatching { el.jsonPrimitive.content }.getOrNull()
        }?.takeIf { it.isNotEmpty() }
    }
}
