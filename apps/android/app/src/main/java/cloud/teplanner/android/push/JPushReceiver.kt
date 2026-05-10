package cloud.teplanner.android.push

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import cn.jpush.android.api.JPushInterface
import cn.jpush.android.api.JPushMessage
import cn.jpush.android.service.JPushMessageReceiver

/**
 * Phase F.4 — JPush registration listener.
 *
 * JPush registers asynchronously after `JPushInterface.init`; the
 * registration ID we need to send to the backend arrives via this
 * broadcast. We hand off to [PushRegistrar] which keeps the value
 * cached and fires off `POST /devices/register` once the user is
 * also authenticated.
 *
 * Wired in AndroidManifest.xml as a `<receiver>` exported by JPush's
 * own service binder.
 */
class JPushReceiver : JPushMessageReceiver() {

    override fun onRegister(context: Context, registrationId: String?) {
        Log.i(TAG, "JPush onRegister: id=${registrationId?.take(12)}…")
        if (!registrationId.isNullOrBlank()) {
            PushRegistrar.onRegistrationId(context.applicationContext, registrationId)
        }
    }

    override fun onConnected(context: Context, isConnected: Boolean) {
        Log.i(TAG, "JPush onConnected: $isConnected")
        if (isConnected) {
            // Connection established — registration ID may already be
            // available even if we missed the onRegister broadcast (e.g.
            // app was killed before init finished last launch).
            val rid = JPushInterface.getRegistrationID(context)
            if (!rid.isNullOrBlank()) {
                PushRegistrar.onRegistrationId(context.applicationContext, rid)
            }
        }
    }

    override fun onTagOperatorResult(context: Context, msg: JPushMessage?) {
        // No-op for v1 — we don't use tags.
    }

    override fun onAliasOperatorResult(context: Context, msg: JPushMessage?) {
        Log.i(TAG, "JPush alias result: code=${msg?.errorCode} alias=${msg?.alias}")
    }

    companion object {
        private const val TAG = "JPushReceiver"
    }
}
