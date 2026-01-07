package com.teplanner

import android.app.Application
import com.amap.api.maps.MapsInitializer
import com.amap.api.services.core.ServiceSettings
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class TePlannerApp : Application() {

    override fun onCreate() {
        super.onCreate()

        // Initialize AMap SDK
        initAMapSDK()
    }

    private fun initAMapSDK() {
        // Privacy compliance - must be called before using any AMap API
        MapsInitializer.updatePrivacyShow(this, true, true)
        MapsInitializer.updatePrivacyAgree(this, true)

        ServiceSettings.updatePrivacyShow(this, true, true)
        ServiceSettings.updatePrivacyAgree(this, true)
    }
}
