package cloud.teplanner.android

import android.app.Application
import android.util.Log
import dagger.hilt.android.HiltAndroidApp

/**
 * Phase F.3 — application bootstrap.
 *
 * AMap privacy compliance is *not* called here on purpose. Calling
 * `MapsInitializer.updatePrivacyAgree` at app start spins up an
 * internal GL thread that crashes on key-validation failure even
 * if the user never opens the map screen — taking the whole app
 * down. The privacy gate now runs lazily inside `MapScreen` the
 * first time it composes; the surrounding crash there is contained
 * to that screen.
 */
@HiltAndroidApp
class TautomationApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "Tautomation Android booted (Phase F.3)")
    }

    companion object {
        private const val TAG = "Tautomation"
    }
}
