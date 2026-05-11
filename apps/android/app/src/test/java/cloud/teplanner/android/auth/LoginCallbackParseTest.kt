package cloud.teplanner.android.auth

import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Tesla OAuth callback JSON parser tests. Mirrors iOS
 * LoginViewModel.parseCallback tests — the auth-data <div> payload
 * has a few historical shapes (token / access_token / auth_token;
 * user_id as int or string; the WKWebView/Android WebView injects
 * JSON-encoded-with-outer-quotes etc). These tests pin all of them.
 */
class LoginCallbackParseTest {

    private fun makeVm(): LoginViewModel {
        // parseCallback doesn't touch any of the injected deps —
        // simplest path is to mock them out as relaxed mocks.
        return LoginViewModel(
            authApi = mockk(relaxed = true),
            authRepository = mockk(relaxed = true),
        )
    }

    @Test
    fun `parses canonical token + user_id int`() {
        val raw = """{"token":"jwt.abc.123","user_id":42}"""
        val parsed = makeVm().parseCallback(raw)
        assertEquals("jwt.abc.123", parsed?.token)
        assertEquals(42L, parsed?.userId)
    }

    @Test
    fun `accepts access_token alias`() {
        val raw = """{"access_token":"jwt.xyz","user_id":"99"}"""
        val parsed = makeVm().parseCallback(raw)
        assertEquals("jwt.xyz", parsed?.token)
        assertEquals(99L, parsed?.userId)
    }

    @Test
    fun `accepts auth_token alias`() {
        val raw = """{"auth_token":"jwt.qqq","user_id":7}"""
        val parsed = makeVm().parseCallback(raw)
        assertEquals("jwt.qqq", parsed?.token)
        assertEquals(7L, parsed?.userId)
    }

    @Test
    fun `unescapes backslash-escaped JSON from WebView`() {
        // Android WebView.evaluateJavascript returns the result as a
        // JSON-encoded string; if upstream passes that through
        // un-stripped (or includes escaped inner quotes), parseCallback
        // should unwrap it.
        val raw = """{\"token\":\"jwt.escaped\",\"user_id\":1}"""
        val parsed = makeVm().parseCallback(raw)
        assertEquals("jwt.escaped", parsed?.token)
        assertEquals(1L, parsed?.userId)
    }

    @Test
    fun `returns null for blank or non-JSON content`() {
        val vm = makeVm()
        assertNull(vm.parseCallback(null))
        assertNull(vm.parseCallback(""))
        assertNull(vm.parseCallback("   "))
        assertNull(vm.parseCallback("<html>not json</html>"))
    }

    @Test
    fun `returns null token but parses user_id when token field missing`() {
        val raw = """{"user_id":12}"""
        val parsed = makeVm().parseCallback(raw)
        assertNull(parsed?.token)
        assertEquals(12L, parsed?.userId)
    }

    @Test
    fun `extra unknown fields ignored`() {
        // Backend embeds a "success":true + other fields. Parser
        // should tolerate them.
        val raw = """{"success":true,"token":"abc","user_id":3,"foo":"bar"}"""
        val parsed = makeVm().parseCallback(raw)
        assertEquals("abc", parsed?.token)
        assertEquals(3L, parsed?.userId)
    }
}
