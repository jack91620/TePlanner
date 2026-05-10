// :app — UI shell + AMap + JPush + navigation. Depends on every
// :core:* module so the activity can wire them through Hilt.

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
}

// Per-machine secrets live in apps/android/local.properties (gitignored).
// Three keys are read here:
//   AMAP_API_KEY            — 高德 Android key (fc9c10d4...)
//   JPUSH_APP_KEY           — JPush AppKey (0295a70a...)
//   BACKEND_BASE_URL        — defaults to api.teplanner.cloud
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}
val amapKey: String = localProps.getProperty("AMAP_API_KEY", "")
val jpushAppKey: String = localProps.getProperty("JPUSH_APP_KEY", "")
val backendBaseUrl: String = localProps.getProperty("BACKEND_BASE_URL", "https://api.teplanner.cloud")

android {
    namespace = "cloud.teplanner.android"
    compileSdk = 36
    // F.0 — pin to a build-tools version actually on disk + non-empty.
    // (36.0.0 + 34.0.0 dirs are present but empty stubs from a partial
    // install; 36.1.0 + 37.0.0 are fully populated.)
    buildToolsVersion = "36.1.0"

    defaultConfig {
        applicationId = "com.teplanner.android"
        minSdk = 26          // Android 8.0 — covers ~98% of mainland
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"

        // Surface secrets via BuildConfig (read at runtime by the
        // bootstrap code in TautomationApplication / NetworkModule).
        buildConfigField("String", "BACKEND_BASE_URL", "\"$backendBaseUrl\"")
        buildConfigField("String", "AMAP_API_KEY", "\"$amapKey\"")
        buildConfigField("String", "JPUSH_APP_KEY", "\"$jpushAppKey\"")

        // 高德 Android SDK 通过 manifest meta-data 读 key — placeholder
        // keeps the manifest declarative + lets per-flavor overrides
        // change keys without manifest edits.
        manifestPlaceholders["AMAP_API_KEY"] = amapKey
        // JPush SDK manifest uses ${JPUSH_APPKEY} (no underscore between
        // APP and KEY) and ${JPUSH_CHANNEL}. Both are required.
        manifestPlaceholders["JPUSH_APPKEY"] = jpushAppKey
        manifestPlaceholders["JPUSH_CHANNEL"] = "developer-default"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            isDebuggable = true
            // No applicationIdSuffix — AMap key is bound to the
            // base package name + signing-cert SHA1. A `.debug` suffix
            // would force registering a second AMap key for dev. Cost
            // of dropping it: debug + release builds can't coexist on
            // a device. Acceptable for solo F.x dev.
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    // 高德 SDK 携带 32-bit native libs — limit to the 64-bit ABIs that
    // every modern 中国 device (Mi/Huawei/OPPO/vivo) ships.
    splits {
        abi {
            isEnable = false
        }
    }
    packaging {
        jniLibs {
            useLegacyPackaging = false
            // Drop 32-bit slice — Play Store + 主流应用商店都 64-only。
            excludes += setOf("**/armeabi/*.so", "**/x86/*.so", "**/mips/*.so")
        }
        resources {
            excludes += setOf("META-INF/AL2.0", "META-INF/LGPL2.1")
        }
    }
}

dependencies {
    implementation(project(":core:network"))
    implementation(project(":core:push"))
    implementation(project(":core:ui"))

    // Compose BOM — pins every Compose artifact to one consistent set.
    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(composeBom)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.navigation:navigation-compose:2.8.4")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    // F.2 — :core:network exposes JsonObject + we pretty-print rule
    // specs in the detail screen.
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    // Compose drag-to-reorder for the automation list — mirrors iOS
    // List + .onMove. Compose stdlib doesn't ship one.
    implementation("sh.calvin.reorderable:reorderable:2.4.0")

    // DI
    implementation("com.google.dagger:hilt-android:2.51.1")
    ksp("com.google.dagger:hilt-android-compiler:2.51.1")
    implementation("androidx.hilt:hilt-navigation-compose:1.2.0")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    // 加密 SharedPreferences (auth token storage)
    implementation("androidx.security:security-crypto-ktx:1.1.0-alpha07")

    // 高德地图 — Phase F.3。
    // Maven coords publish as `.jar` (not `.aar`); JARs bundle native
    // libs under `lib/<abi>/` — AGP packs them into the APK.
    // 3dmap bundles a trimmed location subset (DPoint, UmidtokenInfo)
    // and search bundles a utils-core subset that overlaps with the
    // standalone location JAR — exclude location entirely + take the
    // location bits 3dmap ships. Then add the standalone search JAR
    // with the overlapping utils.core package excluded.
    implementation("com.amap.api:3dmap:9.8.2")
    implementation("com.amap.api:search:9.7.1") {
        exclude(group = "com.amap.api", module = "location")
    }

    // JPush — Phase F.4. AppKey reads from BuildConfig.JPUSH_APP_KEY
    // which is sourced from local.properties.
    implementation("cn.jiguang.sdk:jpush:5.6.1")
    implementation("cn.jiguang.sdk:jcore:4.8.5")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation(composeBom)
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
