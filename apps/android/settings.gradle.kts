// Phase F — TePlanner Android root settings.
//
// `apps/android/` is the Android Studio project root. The shared
// OpenAPI Kotlin SDK lives at `packages/clients/kotlin` and is
// included as a composite build participant so the network layer
// can `implementation(project(":sdk-kotlin"))` without a publish step.

pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
        // 高德 / JPush SDK Maven 镜像
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        // JPush 极光 Maven
        maven { url = uri("https://repo.huaweicloud.com/repository/maven/") }
        maven { url = uri("https://maven.jiguang.cn/") }
    }
}

rootProject.name = "tautomation-android"

include(":app")
include(":core:network")
include(":core:push")
include(":core:ui")
