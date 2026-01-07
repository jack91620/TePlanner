package com.teplanner.di

import android.content.Context
import com.teplanner.map.AMapManager
import com.teplanner.map.GeocodeManager
import com.teplanner.map.PoiSearchManager
import com.teplanner.map.RoutePOISearchManager
import com.teplanner.map.RouteSearchManager
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object MapModule {

    @Provides
    @Singleton
    fun provideAMapManager(
        @ApplicationContext context: Context
    ): AMapManager {
        return AMapManager(context)
    }

    @Provides
    @Singleton
    fun provideRouteSearchManager(
        @ApplicationContext context: Context
    ): RouteSearchManager {
        return RouteSearchManager(context)
    }

    @Provides
    @Singleton
    fun provideRoutePOISearchManager(
        @ApplicationContext context: Context
    ): RoutePOISearchManager {
        return RoutePOISearchManager(context)
    }

    @Provides
    @Singleton
    fun providePoiSearchManager(
        @ApplicationContext context: Context
    ): PoiSearchManager {
        return PoiSearchManager(context)
    }

    @Provides
    @Singleton
    fun provideGeocodeManager(
        @ApplicationContext context: Context
    ): GeocodeManager {
        return GeocodeManager(context)
    }
}
