package cloud.teplanner.android

import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Named
import javax.inject.Singleton

/**
 * Phase F.1 — bridges :core:network's `@Named("backendBaseUrl")`
 * binding to the value local.properties → BuildConfig set in :app's
 * build.gradle.kts. Keeps :core:network agnostic of the BuildConfig
 * generation chain.
 */
@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    @Named("backendBaseUrl")
    fun provideBackendBaseUrl(): String = BuildConfig.BACKEND_BASE_URL
}
