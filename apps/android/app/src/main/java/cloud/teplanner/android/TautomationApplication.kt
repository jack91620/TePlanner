package cloud.teplanner.android

import android.app.Application
import android.util.Log
import cn.jpush.android.api.JPushInterface
import cloud.teplanner.android.util.FeatureFlags
import dagger.hilt.android.HiltAndroidApp

/**
 * Phase F.4 — application bootstrap with JPush init.
 *
 * AMap privacy compliance stays lazy in MapScreen (see F.3 docstring
 * history). JPush, on the other hand, *needs* `Application.onCreate`
 * — its registration thread expects to start with the process and
 * the registration ID won't be ready in time otherwise.
 *
 * Note: JPush schedules a background bind to its servers; the
 * registration ID arrives via broadcast (handled in
 * [push.JPushReceiver]), not synchronously.
 */
@HiltAndroidApp
class TautomationApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        FeatureFlags.setInternalBuildFlag(BuildConfig.DEBUG)
        bootstrapJPush()
        Log.i(TAG, "Tautomation Android booted (Phase F.4)")
    }

    private fun bootstrapJPush() {
        // 5.6.1 dropped setAuth — privacy consent now lives in
        // JCollectionAuth elsewhere; calling init implies consent for v1.
        // A proper PIPL-compliant gate lands in F.4 polish.
        JPushInterface.setDebugMode(true)
        JPushInterface.init(this)
        Log.i(TAG, "JPush init dispatched (registration_id arrives via broadcast)")
    }

    companion object {
        private const val TAG = "Tautomation"
    }
}
