// Top-level build file. Plugin versions are declared here and
// applied false; each module re-declares the plugins it actually
// needs. Kotlin / AGP versions are pinned for reproducibility.

plugins {
    // F.0 — bumped from 8.7.3: AGP 8.7 only understands SDK XML
    // schema v3, but SDK Platform 16 (android-36.1) ships with schema
    // v4, causing "Failed to find target with hash string 'android-36'"
    // even when the platform is on disk. AGP 8.8.x adds schema v4
    // support and is the highest version still compatible with our
    // Gradle 8.10.2 wrapper (8.9+ would force a Gradle 8.11.1 bump).
    id("com.android.application") version "8.8.2" apply false
    id("com.android.library") version "8.8.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
    id("com.google.dagger.hilt.android") version "2.51.1" apply false
    id("com.google.devtools.ksp") version "2.0.21-1.0.27" apply false
}
