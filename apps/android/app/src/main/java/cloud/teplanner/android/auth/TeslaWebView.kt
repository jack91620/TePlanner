package cloud.teplanner.android.auth

import android.annotation.SuppressLint
import android.net.Uri
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView

/**
 * Compose wrapper around android.webkit.WebView that loads the
 * Tesla OAuth URL and watches every navigation. When the URL hits
 * the backend callback path (/auth/tesla/callback), we let the page
 * finish loading, evaluate JS to read the `<div id="auth-data">`
 * JSON payload the backend embedded, then hand (code, state,
 * pageContent) back to the caller.
 *
 * Mirrors iOS TeslaWebView. Browser identity is full app-private
 * — we don't share cookies with the system browser, so prior
 * logins don't follow the user in/out of the OAuth WebView.
 */
@Composable
fun TeslaWebView(
    authUrl: String,
    onCallback: (code: String, state: String, pageContent: String?) -> Unit,
    onLoadError: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var captured = remember { mutableStateHolder() }

    AndroidView(
        modifier = modifier,
        factory = { context ->
            @SuppressLint("SetJavaScriptEnabled")
            val webView = WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                CookieManager.getInstance().setAcceptCookie(true)
                CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView, url: String) {
                        if (captured.value) return
                        if (!url.contains("/auth/tesla/callback")) return

                        val uri = Uri.parse(url)
                        val code = uri.getQueryParameter("code").orEmpty()
                        val state = uri.getQueryParameter("state").orEmpty()

                        val js = """
                            (function() {
                              var el = document.getElementById('auth-data');
                              if (el) return el.textContent || el.innerText || "";
                              return document.body ? document.body.innerText : "";
                            })();
                        """.trimIndent()
                        view.evaluateJavascript(js) { result ->
                            if (captured.value) return@evaluateJavascript
                            captured.value = true
                            val pageContent = unquoteJsResult(result)
                            onCallback(code, state, pageContent)
                        }
                    }

                    override fun onReceivedError(
                        view: WebView,
                        request: WebResourceRequest?,
                        error: android.webkit.WebResourceError?,
                    ) {
                        if (request?.isForMainFrame != true) return
                        onLoadError(error?.description?.toString() ?: "网页加载失败")
                    }
                }
                loadUrl(authUrl)
            }
            webView
        },
    )
}

private class MutableBoolHolder {
    var value: Boolean = false
}

private fun mutableStateHolder() = MutableBoolHolder()

/**
 * evaluateJavascript returns the result as a JSON-encoded string,
 * e.g. `"{\"token\":\"abc\",\"user_id\":123}"` (note the outer
 * quotes + escaped inner quotes). Strip + unescape so the caller
 * sees the raw JSON payload — same shape iOS sees from
 * WKWebView.evaluateJavaScript.
 */
private fun unquoteJsResult(result: String?): String? {
    if (result == null || result == "null") return null
    if (result.length >= 2 && result.startsWith("\"") && result.endsWith("\"")) {
        return result.substring(1, result.length - 1)
            .replace("\\\\", "\\")
            .replace("\\\"", "\"")
            .replace("\\n", "\n")
            .replace("\\r", "\r")
            .replace("\\t", "\t")
    }
    return result
}
