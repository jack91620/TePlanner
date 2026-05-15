package cloud.teplanner.android.util

import android.content.SharedPreferences
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the FeatureFlags registry contract — particularly the production
 * default for ChargingPlanning (must remain OFF until the multi-stop
 * trip pipeline graduates from internal testing). Mirrors iOS
 * FeatureFlagsTests.
 *
 * Uses a fake SharedPreferences (mutable map) so the test doesn't need
 * a Context or Robolectric. Drives the SharedPreferences-direct
 * overloads on FeatureFlags.
 */
class FeatureFlagsTest {

    private val backing = mutableMapOf<String, Boolean>()
    private val prefs = FakeSharedPreferences(backing)

    @After fun tearDown() { backing.clear() }

    @Test fun `chargingPlanning defaults to OFF`() {
        // Play Store users must NOT see the planning entry until we
        // re-enable. Regressions here break the v1.0 hide-feature promise.
        assertFalse(FeatureFlags.isOn(prefs, FeatureFlags.Flag.ChargingPlanning))
        assertFalse(FeatureFlags.Flag.ChargingPlanning.default)
    }

    @Test fun `override takes effect immediately`() {
        FeatureFlags.setOverride(prefs, FeatureFlags.Flag.ChargingPlanning, true)
        assertTrue(FeatureFlags.isOn(prefs, FeatureFlags.Flag.ChargingPlanning))

        FeatureFlags.setOverride(prefs, FeatureFlags.Flag.ChargingPlanning, false)
        assertFalse(FeatureFlags.isOn(prefs, FeatureFlags.Flag.ChargingPlanning))
    }

    @Test fun `null override restores default`() {
        FeatureFlags.setOverride(prefs, FeatureFlags.Flag.ChargingPlanning, true)
        FeatureFlags.setOverride(prefs, FeatureFlags.Flag.ChargingPlanning, null)
        assertFalse(FeatureFlags.isOn(prefs, FeatureFlags.Flag.ChargingPlanning))
    }

    @Test fun `every flag has metadata + feature namespace`() {
        for (flag in FeatureFlags.Flag.all()) {
            assertTrue("${flag.key} key missing prefix", flag.key.startsWith("feature."))
            assertTrue("${flag.name} displayName empty", flag.displayName.isNotEmpty())
            assertTrue("${flag.name} description empty", flag.description.isNotEmpty())
        }
    }

    @Test fun `flag count matches iOS registry`() {
        // Currently 1 flag (chargingPlanning) — mirrors iOS exactly.
        // When this asserts changes, update the iOS registry in lockstep
        // or per-platform divergence will surprise users on the other OS.
        assertEquals(1, FeatureFlags.Flag.all().size)
    }
}

/**
 * Minimal in-memory SharedPreferences for tests. Only implements the
 * methods FeatureFlags actually touches; everything else returns the
 * default the API contract demands.
 */
private class FakeSharedPreferences(
    private val backing: MutableMap<String, Boolean>,
) : SharedPreferences {
    override fun getAll(): MutableMap<String, *> = backing.toMutableMap()
    override fun getString(key: String?, defValue: String?) = defValue
    override fun getStringSet(key: String?, defValues: MutableSet<String>?) = defValues
    override fun getInt(key: String?, defValue: Int) = defValue
    override fun getLong(key: String?, defValue: Long) = defValue
    override fun getFloat(key: String?, defValue: Float) = defValue
    override fun getBoolean(key: String?, defValue: Boolean): Boolean =
        backing[key] ?: defValue
    override fun contains(key: String?): Boolean = backing.containsKey(key)
    override fun edit(): SharedPreferences.Editor = FakeEditor(backing)
    override fun registerOnSharedPreferenceChangeListener(
        l: SharedPreferences.OnSharedPreferenceChangeListener?
    ) {}
    override fun unregisterOnSharedPreferenceChangeListener(
        l: SharedPreferences.OnSharedPreferenceChangeListener?
    ) {}
}

private class FakeEditor(
    private val backing: MutableMap<String, Boolean>,
) : SharedPreferences.Editor {
    override fun putString(key: String?, value: String?) = this
    override fun putStringSet(key: String?, values: MutableSet<String>?) = this
    override fun putInt(key: String?, value: Int) = this
    override fun putLong(key: String?, value: Long) = this
    override fun putFloat(key: String?, value: Float) = this
    override fun putBoolean(key: String?, value: Boolean): SharedPreferences.Editor {
        if (key != null) backing[key] = value
        return this
    }
    override fun remove(key: String?): SharedPreferences.Editor {
        if (key != null) backing.remove(key)
        return this
    }
    override fun clear() = this.apply { backing.clear() }
    override fun commit(): Boolean = true
    override fun apply() {}
}
