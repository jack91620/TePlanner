package cloud.teplanner.android.util

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit

/**
 * Lightweight feature-flag registry. Each flag has a hard-coded
 * production default and a SharedPreferences override key — internal
 * builds can flip flags via the Settings screen without shipping a
 * new Play Store binary.
 *
 * Mirrors the iOS [FeatureFlags] registry — keep flag rawValues + the
 * default-value table identical so a tester gets the same product
 * shape on both platforms.
 */
object FeatureFlags {

    enum class Flag(val key: String, val default: Boolean, val displayName: String, val description: String) {
        /**
         * Hides the Hub "充电规划" entry while we polish the multi-stop
         * trip pipeline. Two production bugs surfaced in one evening on
         * iOS (dead feature + destination-key mismatch); v1.0 ships
         * without this surface and we re-enable once stable. Default OFF.
         */
        ChargingPlanning(
            key = "feature.planning.enabled",
            default = false,
            displayName = "充电规划",
            description = "多段充电路线规划与发送至车机。正在打磨中，关闭后 Hub 不显示「充电规划」入口。",
        );

        companion object {
            fun all(): List<Flag> = values().toList()
        }
    }

    private const val PREFS_NAME = "teplanner.feature_flags"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /**
     * Read a flag from a SharedPreferences directly — useful for tests
     * that can't easily construct a Context. Production callers use
     * the [Context] overload.
     */
    fun isOn(prefs: SharedPreferences, flag: Flag): Boolean =
        if (prefs.contains(flag.key)) prefs.getBoolean(flag.key, flag.default) else flag.default

    /**
     * Read a flag. Looks up the SharedPreferences override first (so
     * internal testers can flip via Settings); falls back to the
     * compiled default.
     */
    fun isOn(context: Context, flag: Flag): Boolean = isOn(prefs(context), flag)

    /**
     * Test-friendly variant of [setOverride] that takes the
     * SharedPreferences directly.
     */
    fun setOverride(prefs: SharedPreferences, flag: Flag, value: Boolean?) {
        prefs.edit {
            if (value == null) remove(flag.key) else putBoolean(flag.key, value)
        }
    }

    /**
     * Set the override. Persists across launches. Pass `null` to
     * remove the override and fall back to the default.
     */
    fun setOverride(context: Context, flag: Flag, value: Boolean?) =
        setOverride(prefs(context), flag, value)

    /**
     * True for debug builds and internal-track installs. Matches iOS
     * `FeatureFlags.isInternalBuild` semantics — gates whether the
     * Settings screen shows the flag-override section.
     */
    fun isInternalBuild(): Boolean = BuildConfigShim.DEBUG

    /**
     * Indirection so we don't hard-import the app-module's
     * `BuildConfig` from this util (kept in :app, callers pass the
     * boolean through if they prefer). DEBUG defaults to true; release
     * builds override via [setInternalBuildFlag].
     */
    private object BuildConfigShim {
        @Volatile
        var DEBUG: Boolean = true
    }

    /** Called from Application.onCreate() with [BuildConfig.DEBUG]. */
    fun setInternalBuildFlag(debug: Boolean) {
        BuildConfigShim.DEBUG = debug
    }
}
