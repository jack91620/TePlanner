// :core:ui — shared Compose components (PressableCard equivalent,
// status pills, etc.) — populated as F.2 hub UI lands.

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "cloud.teplanner.android.core.ui"
    compileSdk = 36
    defaultConfig {
        minSdk = 26
        consumerProguardFiles("consumer-rules.pro")
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    api(composeBom)
    api("androidx.compose.material3:material3")
    api("androidx.compose.ui:ui")
    api("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
