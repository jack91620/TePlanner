package cloud.teplanner.android

import android.app.Application
import android.util.Log
import dagger.hilt.android.HiltAndroidApp

/**
 * Phase F.0 — application bootstrap.
 *
 * iOS [TePlannerApp.bootstrapAMapSDK] equivalent (privacy consent +
 * AMap SDK init) is wired in F.3 once the actual AMap Android SDK
 * is added back to dependencies. F.0 just establishes the Hilt
 * application + verifies the toolchain.
 */
@HiltAndroidApp
class TautomationApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "Tautomation Android booted (Phase F.0)")
    }

    companion object {
        private const val TAG = "Tautomation"
    }
}
