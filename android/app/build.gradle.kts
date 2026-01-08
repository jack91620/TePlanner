import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.dagger.hilt.android")
    id("kotlin-parcelize")
    kotlin("kapt")
}

// Load local.properties
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

android {
    namespace = "com.teplanner"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.teplanner"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }

        // AMap API Key from local.properties
        manifestPlaceholders["AMAP_API_KEY"] = localProperties.getProperty("AMAP_API_KEY", "")

        // 支持x86_64模拟器 (使用9.x版本SDK，不支持x86 32位)
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        debug {
            // Backend URL for debug builds - reads from local.properties or uses default
            // For emulator: use 10.0.2.2 (points to host machine's localhost)
            // For real device: use your computer's LAN IP
            val debugUrl = localProperties.getProperty("BACKEND_URL", "http://10.0.2.2:8000/api/v1/")
            buildConfigField("String", "BACKEND_URL", "\"$debugUrl\"")
        }
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Production backend URL
            buildConfigField("String", "BACKEND_URL", "\"https://api.teplanner.com/api/v1/\"")
        }
    }

    buildFeatures {
        buildConfig = true
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
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // Kotlin
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // AndroidX Core
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")

    // Jetpack Compose
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    implementation("androidx.navigation:navigation-compose:2.7.6")

    // Hilt
    implementation("com.google.dagger:hilt-android:2.50")
    kapt("com.google.dagger:hilt-compiler:2.50")
    implementation("androidx.hilt:hilt-navigation-compose:1.1.0")

    // Network
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")

    // Storage
    implementation("androidx.datastore:datastore-preferences:1.0.0")
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")

    // AMap SDK (高德地图) - 使用9.x版本以支持x86_64模拟器
    // 注意: 10.x版本不支持x86架构
    // 参考: https://lbs.amap.com/api/android-sdk/guide/create-project/android-studio-create-project
    // 3dmap已包含location，不需要单独引入location
    implementation("com.amap.api:3dmap:9.8.2")       // 3D地图SDK (包含定位，支持x86_64)
    implementation("com.amap.api:search:9.7.1") {    // 搜索SDK
        // 排除与3dmap重复的工具类
        exclude(group = "com.amap.api", module = "location")
    }

    // WebView (Tesla OAuth)
    implementation("androidx.webkit:webkit:1.9.0")

    // Image Loading
    implementation("io.coil-kt:coil-compose:2.5.0")

    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation(platform("androidx.compose:compose-bom:2024.06.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")

    // Debug
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}

kapt {
    correctErrorTypes = true
}
