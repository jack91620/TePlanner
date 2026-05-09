package cloud.teplanner.android

import android.app.Application
import android.util.Log
import com.amap.api.location.AMapLocationClient
import com.amap.api.maps.MapsInitializer
import com.amap.api.services.core.ServiceSettings
import dagger.hilt.android.HiltAndroidApp

/**
 * Phase F.0 — application bootstrap.
 *
 * Mirrors iOS [TePlannerApp.bootstrapAMapSDK]: every AMap entry-point
 * (Map3D / Search / Location) requires `updatePrivacyShow` +
 * `updatePrivacyAgree` to be called *before* any AMap type is
 * instantiated. JPush we leave un-initialized here; Phase F.4 wires it
 * in once the user has granted notification permission so we don't
 * burn an APNs-equivalent registration before consent.
 */
@HiltAndroidApp
class TautomationApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        bootstrapAMap()
        Log.i(TAG, "Tautomation Android booted")
    }

    private fun bootstrapAMap() {
        // 同意隐私协议后才能初始化 — 与 iOS bootstrapAMapSDK 严格对齐。
        // Phase F.0 假设用户首启时同意；F.1 会在 LoginScreen 加显式
        // 隐私弹窗 + 仅在 Agree 后调用这里。
        MapsInitializer.updatePrivacyShow(this, true, true)
        MapsInitializer.updatePrivacyAgree(this, true)
        AMapLocationClient.updatePrivacyShow(this, true, true)
        AMapLocationClient.updatePrivacyAgree(this, true)
        ServiceSettings.updatePrivacyShow(this, true, true)
        ServiceSettings.updatePrivacyAgree(this, true)
    }

    companion object {
        private const val TAG = "Tautomation"
    }
}
