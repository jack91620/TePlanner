package com.teplanner.ui.vehicle

import android.annotation.SuppressLint
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.hilt.navigation.compose.hiltViewModel
import com.teplanner.ui.theme.*

@Composable
fun VehicleBindingScreen(
    onNavigateBack: () -> Unit,
    onBindingSuccess: () -> Unit,
    viewModel: VehicleBindingViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    var hasNavigated by rememberSaveable { mutableStateOf(false) }

    android.util.Log.d("VehicleBindingScreen", "uiState.bindingSuccess = ${uiState.bindingSuccess}, hasNavigated = $hasNavigated")

    val context = androidx.compose.ui.platform.LocalContext.current

    LaunchedEffect(uiState.bindingSuccess) {
        android.util.Log.d("VehicleBindingScreen", "LaunchedEffect triggered, bindingSuccess = ${uiState.bindingSuccess}, hasNavigated = $hasNavigated")
        if (uiState.bindingSuccess && !hasNavigated) {
            android.util.Log.d("VehicleBindingScreen", "Calling onBindingSuccess() immediately")
            hasNavigated = true
            viewModel.onNavigationComplete() // Clear the success state in ViewModel

            // Try Activity-level navigation as a workaround
            val activity = context as? android.app.Activity
            if (activity != null) {
                android.util.Log.d("VehicleBindingScreen", "Restarting Activity to force navigation")
                val intent = activity.intent
                activity.finish()
                activity.startActivity(intent)
            } else {
                onBindingSuccess()
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBackground)
    ) {
        // Top Bar
        TopBar(
            onClose = onNavigateBack,
            modifier = Modifier.statusBarsPadding()
        )

        when {
            uiState.bindingSuccess -> {
                // Show success state while navigating
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        CircularProgressIndicator(
                            color = TeslaBlue,
                            strokeWidth = 3.dp
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "连接成功!",
                            color = TextPrimary,
                            fontSize = 16.sp
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "正在返回首页...",
                            color = TextSecondary,
                            fontSize = 14.sp
                        )
                    }
                }
            }
            uiState.isLoading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        CircularProgressIndicator(
                            color = TeslaBlue,
                            strokeWidth = 3.dp
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "加载Tesla登录...",
                            color = TextSecondary,
                            fontSize = 14.sp
                        )
                    }
                }
            }
            uiState.authUrl != null && !uiState.bindingSuccess -> {
                TeslaWebView(
                    authUrl = uiState.authUrl!!,
                    onCallbackReceived = { code, state, pageContent ->
                        viewModel.handleCallback(code, state, pageContent)
                    },
                    modifier = Modifier.fillMaxSize()
                )
            }
            uiState.error != null -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(32.dp)
                    ) {
                        Text(
                            text = "连接失败",
                            color = TextPrimary,
                            fontSize = 18.sp
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = uiState.error!!,
                            color = TextSecondary,
                            fontSize = 14.sp
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                        Button(
                            onClick = { viewModel.retry() },
                            colors = ButtonDefaults.buttonColors(containerColor = TeslaBlue)
                        ) {
                            Text("重试")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TopBar(
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "连接Tesla",
            color = TextPrimary,
            fontSize = 18.sp
        )
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(DarkSurface)
                .clickable(onClick = onClose),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "关闭",
                tint = TextPrimary,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun TeslaWebView(
    authUrl: String,
    onCallbackReceived: (code: String, state: String, pageContent: String?) -> Unit,
    modifier: Modifier = Modifier
) {
    val callbackHandledRef = remember { java.util.concurrent.atomic.AtomicBoolean(false) }

    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.userAgentString = settings.userAgentString + " TePlanner/1.0"

                webViewClient = object : WebViewClient() {
                    private var pendingCallbackUrl: String? = null
                    private var pendingCode: String? = null
                    private var pendingState: String? = null

                    override fun shouldOverrideUrlLoading(
                        view: WebView?,
                        request: WebResourceRequest?
                    ): Boolean {
                        val url = request?.url?.toString() ?: return false
                        android.util.Log.d("TeslaWebView", "shouldOverrideUrlLoading: $url")

                        // Check if this is the callback URL - but DON'T intercept it
                        // Let the WebView load it so the backend processes the OAuth code
                        if (url.contains("/auth/tesla/callback")) {
                            val uri = android.net.Uri.parse(url)
                            pendingCode = uri.getQueryParameter("code")
                            pendingState = uri.getQueryParameter("state")
                            pendingCallbackUrl = url
                            android.util.Log.d("TeslaWebView", "Callback URL detected, letting it load: code=$pendingCode, state=$pendingState")
                            // Return false to let the WebView load this URL
                            return false
                        }
                        return false
                    }

                    override fun onPageStarted(
                        view: WebView?,
                        url: String?,
                        favicon: android.graphics.Bitmap?
                    ) {
                        super.onPageStarted(view, url, favicon)
                        android.util.Log.d("TeslaWebView", "onPageStarted: $url")
                    }

                    override fun onPageFinished(view: WebView?, url: String?) {
                        super.onPageFinished(view, url)
                        android.util.Log.d("TeslaWebView", "onPageFinished: $url")

                        // If this is the callback page and we have pending code/state
                        if (url != null && url.contains("/auth/tesla/callback") &&
                            pendingCode != null && pendingState != null &&
                            !callbackHandledRef.get()) {

                            android.util.Log.d("TeslaWebView", "Callback page loaded, extracting response...")

                            // Inject JavaScript to get the auth-data JSON from the hidden div
                            view?.evaluateJavascript(
                                """(function() {
                                    var authDataDiv = document.getElementById('auth-data');
                                    if (authDataDiv && authDataDiv.textContent && authDataDiv.textContent.trim().startsWith('{')) {
                                        return authDataDiv.textContent.trim();
                                    }
                                    return document.body ? document.body.innerText : '';
                                })()"""
                            ) { result ->
                                android.util.Log.d("TeslaWebView", "Page content: $result")

                                if (callbackHandledRef.compareAndSet(false, true)) {
                                    val code = pendingCode!!
                                    val state = pendingState!!
                                    // Remove surrounding quotes from JS result
                                    val content = result?.trim()?.removeSurrounding("\"")
                                    onCallbackReceived(code, state, content)
                                }
                            }
                        }
                    }
                }

                loadUrl(authUrl)
            }
        }
    )
}
