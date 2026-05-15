import SwiftUI
import TePlannerKit

/// Tesla OAuth landing screen. Mirrors the Android `LoginScreen` +
/// `VehicleBindingScreen` pair: the main body is the marketing splash
/// with a "连接 Tesla 账户" call-to-action; tapping it kicks off the
/// view model, which fetches the auth URL and presents the web view.
struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    @State private var showingDebugDemo = false

    /// True when the app is launched with `-debug-ui` (or env
    /// `TEPLANNER_DEBUG_UI=1`). Used to surface the Phase 9/10 banner
    /// preview screen on the login splash.
    private static var debugUIEnabled: Bool {
        CommandLine.arguments.contains("-debug-ui") ||
        ProcessInfo.processInfo.environment["TEPLANNER_DEBUG_UI"] == "1"
    }

    init(apiService: APIServiceProtocol, authSession: AuthSession) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(
            apiService: apiService,
            authSession: authSession
        ))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .ready(let url, _):
                bindingView(authURL: url)
            case .processingCallback:
                ProgressView("正在登录...").controlSize(.large)
            default:
                splash
            }
        }
        .alert("登录失败", isPresented: errorBinding) {
            Button("重试", action: { Task { await viewModel.start() } })
            Button("取消", role: .cancel) {}
        } message: {
            if case .failed(let message) = viewModel.state {
                Text(message)
            }
        }
        .sheet(isPresented: $showingDebugDemo) {
            NavigationStack {
                CommandBannerDemoView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") { showingDebugDemo = false }
                        }
                    }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { if case .failed = viewModel.state { return true } else { return false } },
            set: { _ in }
        )
    }

    private var splash: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("T")
                .font(Tokens.typographySplashLogo)
                .foregroundStyle(.red)
                .frame(width: 160, height: 160)
                .background(Tokens.surfaceCard, in: Circle())

            VStack(spacing: 8) {
                Text("Tautomation")
                    .font(.largeTitle.bold())
                Text("你的特斯拉，更懂你")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                feature(icon: "moon.zzz.fill", text: "露营 / 哨兵 / 充电完成自动提醒")
                feature(icon: "antenna.radiowaves.left.and.right",
                        text: "Telemetry 实时车况，秒级响应")
                feature(icon: "location.fill", text: "进出地理围栏触发自动化")
                feature(icon: "hand.tap.fill", text: "推送通知一键执行车辆动作")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                Task { await viewModel.start() }
            } label: {
                if viewModel.state == .loadingAuthUrl {
                    ProgressView().controlSize(.regular)
                } else {
                    Text("连接 Tesla 账户")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.state == .loadingAuthUrl)
            .padding(.horizontal, 24)
            .padding(.bottom, 4)
            .accessibilityIdentifier("login_button")

            consentLine
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            if Self.debugUIEnabled {
                // DEBUG-only — only renders when app launched with
                // `-debug-ui` flag or `TEPLANNER_DEBUG_UI=1` env. Used
                // to screenshot the Phase 9/10 banner without going
                // through Tesla OAuth.
                Button("UI 演示 (DEBUG)") {
                    showingDebugDemo = true
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
                .accessibilityIdentifier("debug_ui_demo")
            }
        }
    }

    /// 登录页底部的"登录即同意"小字。两个文档链接走系统浏览器
    /// (Link → Safari) 而不是 WKWebView——审核期 Apple 会真访问
    /// 这两个 URL，能在 Safari 打开等于证明链接有效，比内嵌 webview
    /// 更稳妥。Both URLs live in `LegalLinks` so they're easy to
    /// swap when hosting moves.
    private var consentLine: some View {
        Group {
            Text("登录即表示同意 ")
                .foregroundStyle(.secondary) +
            Text("[《用户协议》](\(LegalLinks.termsOfService.absoluteString))")
                .foregroundStyle(.tint) +
            Text(" 与 ")
                .foregroundStyle(.secondary) +
            Text("[《隐私政策》](\(LegalLinks.privacyPolicy.absoluteString))")
                .foregroundStyle(.tint)
        }
        .font(.caption2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("login_consent_line")
    }

    private func feature(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(text)
            Spacer()
        }
    }

    @ViewBuilder
    private func bindingView(authURL: URL) -> some View {
        NavigationStack {
            TeslaWebView(
                authURL: authURL,
                onCallback: { code, state, pageContent in
                    viewModel.handleCallback(code: code, state: state, pageContent: pageContent)
                },
                onLoadError: { _ in
                    // Surface inline next pass — splash + alert handle errors.
                }
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("登录 Tesla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        Task { await viewModel.start() }
                    }
                }
            }
        }
    }
}
