package cloud.teplanner.android.auth

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

/**
 * Thin VM wrapper over [AuthRepository]. Exists so Compose can call
 * `hiltViewModel<AuthSession>()` from any composable and observe
 * the singleton repo without holding a long-lived UI reference to
 * the singleton itself.
 *
 * Tesla OAuth is the only login path; the OAuth state machine
 * lives in [LoginViewModel]. This VM only exposes account state
 * + logout.
 */
@HiltViewModel
class AuthSession @Inject constructor(
    private val repo: AuthRepository,
) : ViewModel() {

    val account: StateFlow<AuthRepository.Account?> = repo.account

    val isAuthenticated: Boolean
        get() = repo.isAuthenticated

    fun logout() = repo.logout()

    suspend fun unbindTesla(): Result<Unit> = repo.unbindTesla()

    suspend fun deleteAccount(): Result<Unit> = repo.deleteAccount()
}
