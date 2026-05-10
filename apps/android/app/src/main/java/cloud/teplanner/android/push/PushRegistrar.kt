package cloud.teplanner.android.push

import android.content.Context
import android.util.Log
import cloud.teplanner.android.core.network.DevicesApi
import cloud.teplanner.android.core.network.RegisterDeviceRequest
import cloud.teplanner.android.core.network.TokenStore
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Phase F.4 — coordinates "we have a registration ID" + "we have an
 * auth token" → fires `POST /devices/register` exactly once per
 * (registration_id, user) pair.
 *
 * Two trigger points:
 *   1. JPushReceiver.onRegister fires while user logged in →
 *      register immediately.
 *   2. AuthSession.login completes after JPush already had the id →
 *      [registerIfPossible] retries with the cached value.
 *
 * Cached in-process; if the app cold-restarts and the auth session
 * is still valid, the next JPushReceiver.onConnected will replay the
 * registration ID and we re-register (cheap — backend upserts).
 */
object PushRegistrar {

    private const val TAG = "PushRegistrar"

    @Volatile private var lastRegistrationId: String? = null
    @Volatile private var lastRegisteredKey: String? = null

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @EntryPoint
    @InstallIn(SingletonComponent::class)
    interface Hilt {
        fun devicesApi(): DevicesApi
        fun tokenStore(): TokenStore
    }

    fun onRegistrationId(context: Context, registrationId: String) {
        lastRegistrationId = registrationId
        registerIfPossible(context)
    }

    /** Call from AuthSession after successful login or token restore. */
    fun registerIfPossible(context: Context) {
        val rid = lastRegistrationId ?: return
        val hilt = EntryPointAccessors.fromApplication(context, Hilt::class.java)
        val token = hilt.tokenStore().accessToken
        if (token.isNullOrBlank()) {
            Log.d(TAG, "skipping register — no auth token yet")
            return
        }
        val userId = hilt.tokenStore().userId
        val key = "$userId:$rid"
        if (key == lastRegisteredKey) {
            Log.d(TAG, "skipping register — already registered $key")
            return
        }
        scope.launch {
            runCatching {
                hilt.devicesApi().register(
                    RegisterDeviceRequest(
                        token = rid,
                        platform = "jpush",
                        providerToken = rid,
                        bundleId = context.packageName,
                    )
                )
            }.onSuccess { resp ->
                Log.i(TAG, "device registered: id=${resp.deviceId}")
                lastRegisteredKey = key
            }.onFailure { err ->
                Log.w(TAG, "device register failed: ${err.message}")
            }
        }
    }
}
