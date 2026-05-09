// :core:network — auth interceptor, Retrofit / OkHttp wiring,
// re-exports the generated Kotlin SDK at packages/clients/kotlin
// (Phase F.1 imports it; for now just provides a clean DI surface).

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
}

android {
    namespace = "cloud.teplanner.android.core.network"
    compileSdk = 36
    buildToolsVersion = "36.1.0"
    defaultConfig {
        minSdk = 26
        consumerProguardFiles("consumer-rules.pro")
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { buildConfig = true }
}

dependencies {
    // Generated OpenAPI SDK lives outside this Gradle build; we
    // depend on it as a flat-jar via a local Maven `mavenLocal()` if
    // it's been published, or directly as files in F.1 once the
    // codegen flow is wired into the gradle composite-build.
    // For now (F.0) we only declare HTTP + DI deps so the module
    // compiles standalone.

    implementation("com.google.dagger:hilt-android:2.51.1")
    ksp("com.google.dagger:hilt-android-compiler:2.51.1")

    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-kotlinx-serialization:2.11.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("androidx.security:security-crypto-ktx:1.1.0-alpha07")
}
