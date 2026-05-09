package cloud.teplanner.android.core.network

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Phase F.1 — Android equivalent of iOS [KeychainStorage]. JWT +
 * `user_id` survive process restarts. Backed by AndroidX
 * EncryptedSharedPreferences (AES-256-GCM, key in StrongBox where
 * available, falls back to TEE → AndroidKeyStore software).
 *
 * Plain `SharedPreferences` is insufficient: a bearer JWT is a
 * full credential — anyone with file-system access (rooted device,
 * adb pull when debuggable) could read it back. Encrypted version
 * is the standard answer.
 *
 * Lifecycle:
 *   - `save(token, userId)` after successful POST /auth/login
 *   - `clear()` on logout / token expiry / 401 from any endpoint
 *   - `accessToken` and `userId` read by [AuthInterceptor] + the
 *     in-memory [AuthSession] view-model.
 */
class TokenStore(context: Context) {
    private val masterKey: MasterKey =
        MasterKey.Builder(context.applicationContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

    private val prefs = EncryptedSharedPreferences.create(
        context.applicationContext,
        FILE_NAME,
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    val accessToken: String?
        get() = prefs.getString(KEY_TOKEN, null)

    val userId: Long?
        get() = if (prefs.contains(KEY_USER_ID)) prefs.getLong(KEY_USER_ID, -1) else null

    val email: String?
        get() = prefs.getString(KEY_EMAIL, null)

    fun save(token: String, userId: Long, email: String) {
        prefs.edit()
            .putString(KEY_TOKEN, token)
            .putLong(KEY_USER_ID, userId)
            .putString(KEY_EMAIL, email)
            .apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val FILE_NAME = "tautomation_auth"
        private const val KEY_TOKEN = "access_token"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_EMAIL = "email"
    }
}
