import SwiftUI
import WebKit
import TePlannerKit

/// SwiftUI wrapper around `WKWebView` that loads the Tesla OAuth URL and
/// watches every navigation. When the URL hits the backend's callback
/// path (`/auth/tesla/callback?...`), it lets the page finish loading,
/// scrapes the JSON the backend embeds in `<div id="auth-data">`, and
/// hands the captured `(code, state, pageContent)` back to the caller.
///
/// The actual login state machine lives in `LoginViewModel`; this view
/// is just plumbing.
struct TeslaWebView: UIViewRepresentable {
    let authURL: URL
    let onCallback: (_ code: String, _ state: String, _ pageContent: String?) -> Void
    let onLoadError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCallback: onCallback, onLoadError: onLoadError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        Log.oauth.notice("TeslaWebView loading \(authURL.absoluteString, privacy: .public)")
        webView.load(URLRequest(url: authURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onCallback: (String, String, String?) -> Void
        private let onLoadError: (Error) -> Void
        private var capturedCallback = false

        init(
            onCallback: @escaping (String, String, String?) -> Void,
            onLoadError: @escaping (Error) -> Void
        ) {
            self.onCallback = onCallback
            self.onLoadError = onLoadError
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let urlString = webView.url?.absoluteString ?? "?"
            Log.oauth.debug("WKWebView didFinish: \(urlString, privacy: .public)")

            guard !capturedCallback,
                  let url = webView.url,
                  url.path.contains("/auth/tesla/callback") else {
                return
            }

            Log.oauth.notice("callback URL hit: \(url.path, privacy: .public)")
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let code = components?.queryItems?.first(where: { $0.name == "code" })?.value ?? ""
            let state = components?.queryItems?.first(where: { $0.name == "state" })?.value ?? ""

            let js = """
            (function() {
              var el = document.getElementById('auth-data');
              if (el) return el.textContent || el.innerText || "";
              return document.body ? document.body.innerText : "";
            })();
            """

            webView.evaluateJavaScript(js) { [weak self] result, error in
                guard let self else { return }
                if self.capturedCallback { return }
                if let error {
                    Log.oauth.error("JS extract failed: \(error.localizedDescription, privacy: .public)")
                }
                self.capturedCallback = true
                let pageContent = result as? String
                Log.oauth.notice("callback handed off (code prefix=\(code.prefix(6), privacy: .public)…, body=\(pageContent?.count ?? 0, privacy: .public) chars)")
                self.onCallback(code, state, pageContent)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Log.oauth.error("WKWebView didFail: \(error.localizedDescription, privacy: .public)")
            onLoadError(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Log.oauth.error("WKWebView didFailProvisionalNavigation: \(error.localizedDescription, privacy: .public)")
            onLoadError(error)
        }
    }
}
