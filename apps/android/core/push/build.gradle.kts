// :core:push — JPush wrapper + OEM channel registration helpers.
// F.4 wires this into POST /devices/register with platform=jpush
// and the registration_id JPush hands back at install time.

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
}

android {
    namespace = "cloud.teplanner.android.core.push"
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
}

dependencies {
    implementation("com.google.dagger:hilt-android:2.51.1")
    ksp("com.google.dagger:hilt-android-compiler:2.51.1")
    // JPush wired in F.4 — coords pinned then once registered
    // org name is verified against the live JPush console.
    // implementation("cn.jiguang.sdk:jpush:5.6.1")
    // implementation("cn.jiguang.sdk:jcore:4.8.5")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
