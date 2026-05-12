package cloud.teplanner.android.hub.quickactions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import cloud.teplanner.android.core.network.ShareCreateRequest
import cloud.teplanner.android.core.network.ShareDetailResponse
import cloud.teplanner.android.core.network.ShareType
import cloud.teplanner.android.core.network.SharesApi
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * Drives the share / import flows. Owns:
 *   - createShareForAction(action): POST /shares with the
 *     SharedActionPayload wire format, emits result for the
 *     UI to render ShareCodeSheet
 *   - lookupShare(code): GET /shares/{code}, emits the
 *     ShareDetailResponse for ImportShareSheet to preview
 *   - importIntoLibrary(detail): decode the payload into a
 *     HubAction (via SharedActionPayload.toHubAction()) and
 *     hand to HubActionsStore.importAction (which applies the
 *     " 副本" disambiguator if the name collides)
 *
 * Errors map to friendly Chinese copy in [friendlyError].
 */
@HiltViewModel
class ShareViewModel @Inject constructor(
    private val sharesApi: SharesApi,
    private val store: HubActionsStore,
) : ViewModel() {

    sealed class CreateState {
        object Idle : CreateState()
        object Creating : CreateState()
        data class Success(val detail: ShareDetailResponse) : CreateState()
        data class Failed(val message: String) : CreateState()
    }

    sealed class LookupState {
        object Idle : LookupState()
        object Looking : LookupState()
        data class Preview(val detail: ShareDetailResponse) : LookupState()
        data class Imported(val name: String, val type: ShareType) : LookupState()
        data class Failed(val message: String) : LookupState()
    }

    private val json: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val _createState = MutableStateFlow<CreateState>(CreateState.Idle)
    val createState: StateFlow<CreateState> = _createState.asStateFlow()

    private val _lookupState = MutableStateFlow<LookupState>(LookupState.Idle)
    val lookupState: StateFlow<LookupState> = _lookupState.asStateFlow()

    fun createShareForAction(action: HubAction, appVersion: String? = null) {
        _createState.value = CreateState.Creating
        val payload = SharedActionPayload.from(action)
        val payloadMap = encodeShareablePayload(payload, json) ?: run {
            _createState.value = CreateState.Failed("无法编码分享内容")
            return
        }
        viewModelScope.launch {
            runCatching {
                sharesApi.create(
                    ShareCreateRequest(
                        shareType = ShareType.ACTION,
                        payload = payloadMap,
                        expiresInDays = 30,
                        minAppVersion = appVersion,
                    )
                )
            }.onSuccess { detail ->
                _createState.value = CreateState.Success(detail)
            }.onFailure { err ->
                _createState.value = CreateState.Failed(friendlyError(err))
            }
        }
    }

    fun lookupShare(code: String, appVersion: String? = null) {
        _lookupState.value = LookupState.Looking
        val normalized = code.replace("-", "").replace(" ", "").trim().uppercase()
        viewModelScope.launch {
            runCatching {
                sharesApi.lookup(code = normalized, appVersion = appVersion)
            }.onSuccess { detail ->
                _lookupState.value = LookupState.Preview(detail)
            }.onFailure { err ->
                _lookupState.value = LookupState.Failed(friendlyError(err))
            }
        }
    }

    fun importPreviewIntoLibrary() {
        val detail = (_lookupState.value as? LookupState.Preview)?.detail ?: return
        when (detail.shareType) {
            ShareType.ACTION -> {
                val decoded = decodeAction(detail) ?: run {
                    _lookupState.value = LookupState.Failed("分享内容损坏，无法导入")
                    return
                }
                val action = decoded.toHubAction()
                viewModelScope.launch {
                    store.importAction(action)
                    _lookupState.value = LookupState.Imported(decoded.name, ShareType.ACTION)
                }
            }
            ShareType.RULE -> {
                // Rule import wires into AutomationRulesStore — port
                // lands alongside the cross-platform rule-share flow.
                _lookupState.value = LookupState.Failed("规则分享导入暂不支持（即将到来）")
            }
        }
    }

    fun resetCreate() { _createState.update { CreateState.Idle } }
    fun resetLookup() { _lookupState.update { LookupState.Idle } }

    private fun decodeAction(detail: ShareDetailResponse): SharedActionPayload? {
        return runCatching {
            val text = json.encodeToString(
                kotlinx.serialization.serializer<Map<String, kotlinx.serialization.json.JsonElement>>(),
                detail.payload,
            )
            json.decodeFromString(SharedActionPayload.serializer(), text)
        }.getOrNull()
    }

    /// Mirrors iOS friendly() in ImportShareSheet — translate HTTP
    /// status codes into Chinese copy the user can understand.
    private fun friendlyError(err: Throwable): String {
        // Retrofit's HttpException carries `code()`; we read via
        // reflection-light pattern since DI-isolated tests may not
        // import retrofit2.HttpException.
        val message = err.message ?: "网络错误"
        return when {
            "404" in message || "not found" in message.lowercase() -> "分享码不存在，请检查后重试"
            "410" in message -> "分享码已过期或被分享者撤销"
            "412" in message -> "需要更新 App 才能导入这个分享码"
            else -> message
        }
    }
}
