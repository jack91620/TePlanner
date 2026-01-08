pluginManagement {
    repositories {
        // Chinese mirrors (uncomment if needed)
        // maven { url = uri("https://maven.aliyun.com/repository/google") }
        // maven { url = uri("https://maven.aliyun.com/repository/central") }
        // maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // AMap SDK repository (高德地图)
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/jcenter") }
        maven { url = uri("https://jitpack.io") }
    }
}

rootProject.name = "TePlanner"
include(":app")
