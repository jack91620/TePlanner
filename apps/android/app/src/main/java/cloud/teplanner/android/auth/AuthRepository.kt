package cloud.teplanner.android.auth

import android.content.Context
import cloud.teplanner.android.core.network.TokenStore
import cloud.teplanner.android.push.PushRegistrar
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Process-wide auth state holder. Lives one tier below [AuthSession]
 * (the VM) so other Hilt-injected VMs (LoginViewModel) can depend on
 * it — Hilt rejects ViewModel→ViewModel constructor injection.
 *
 * Direct port of the iOS [AuthSession] responsibility minus the
 * Combine plumbing.
 */
@Singleton
class AuthRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val tokenStore: TokenStore,
) {
    data class Account(
        val userId: Long,
        val email: String?,
        val nickname: String?,
    )

    private val _account = MutableStateFlow(currentAccount())
    val account: StateFlow<Account?> = _account.asStateFlow()

    init {
        if (isAuthenticated) {
            PushRegistrar.registerIfPossible(context)
        }
    }

    val isAuthenticated: Boolean
        get() = tokenStore.accessToken != null

    fun login(token: String, userId: Long, email: String? = null, nickname: String? = null) {
        tokenStore.save(token, userId, email)
        _account.value = Account(userId, email, nickname)
        PushRegistrar.registerIfPossible(context)
    }

    fun logout() {
        tokenStore.clear()
        _account.value = null
    }

    private fun currentAccount(): Account? {
        val id = tokenStore.userId ?: return null
        return Account(id, tokenStore.email, null)
    }
}
