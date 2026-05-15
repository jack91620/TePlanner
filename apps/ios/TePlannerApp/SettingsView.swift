import SwiftUI
import TePlannerKit
import UserNotifications

/// 设置页 — 偏好、关于、调试入口。Reachable from the hub menu.
/// Intentionally short for v1: the app's automation settings live
/// per-rule, this is the place for cross-cutting prefs.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pushStatus: PushStatus = .unknown
    private let appVersion: String
    private let buildNumber: String
    private let apiService: APIServiceProtocol?

    enum PushStatus { case unknown, authorized, provisional, denied, notDetermined, ephemeral }

    init(apiService: APIServiceProtocol? = nil) {
        let info = Bundle.main.infoDictionary
        self.appVersion = info?["CFBundleShortVersionString"] as? String ?? "0.0"
        self.buildNumber = info?["CFBundleVersion"] as? String ?? "0"
        self.apiService = apiService
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("推送权限", systemImage: pushStatusIcon)
                            .foregroundStyle(pushStatusColor)
                        Spacer()
                        Text(pushStatusLabel)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(pushStatusColor)
                    }
                    Button {
                        openSystemNotifications()
                    } label: {
                        HStack {
                            Label("系统通知设置", systemImage: "bell.badge.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    Button {
                        LocalNotificationScheduler.shared.fireSample(
                            title: "Tautomation 测试通知",
                            body: "如果你看到这条，推送通知工作正常。",
                            identifier: "settings_diagnostic",
                        )
                    } label: {
                        Label("发送测试通知", systemImage: "paperplane.fill")
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("通知")
                } footer: {
                    Text("Tautomation 通过系统通知中心推送自动化提醒。可在系统设置里调整声音、横幅样式等。「发送测试通知」会在 1 秒后弹出一条样例消息——前台或锁屏都能验证。")
                }

                Section {
                    if let api = apiService {
                        NavigationLink {
                            RecentFiresView(apiService: api)
                        } label: {
                            Label("活动 (触发记录)", systemImage: "clock.arrow.circlepath")
                        }
                    }
                    if let api = apiService {
                        NavigationLink {
                            AutomationOrderResetView(apiService: api)
                        } label: {
                            Label("重置自定义排序", systemImage: "arrow.up.arrow.down")
                        }
                    }
                } header: {
                    Text("自动化")
                } footer: {
                    Text("活动 — 查看最近的规则触发推送时间线。\n重置自定义排序 — 将自动化列表恢复为默认顺序。")
                }

                Section {
                    LabeledContent("版本", value: "\(appVersion) (\(buildNumber))")
                } header: {
                    Text("关于")
                } footer: {
                    Text("升级 App 不会丢失自动化规则、出行计划、充电限额等设置——"
                         + "这些数据与你的 Tesla 账户绑定，重新安装也会自动同步回来。")
                        .font(.caption2)
                }

                if FeatureFlags.isInternalBuild {
                    FeatureFlagsSection()
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                await refreshPushStatus()
            }
        }
    }

    private func refreshPushStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            switch settings.authorizationStatus {
            case .authorized:    pushStatus = .authorized
            case .provisional:   pushStatus = .provisional
            case .denied:        pushStatus = .denied
            case .notDetermined: pushStatus = .notDetermined
            case .ephemeral:     pushStatus = .ephemeral
            @unknown default:    pushStatus = .unknown
            }
        }
    }

    private var pushStatusIcon: String {
        switch pushStatus {
        case .authorized, .provisional: return "checkmark.circle.fill"
        case .denied:                   return "xmark.circle.fill"
        case .notDetermined:            return "questionmark.circle.fill"
        case .ephemeral, .unknown:      return "circle"
        }
    }

    private var pushStatusColor: Color {
        switch pushStatus {
        case .authorized, .provisional: return .green
        case .denied:                   return .red
        case .notDetermined:            return .orange
        case .ephemeral, .unknown:      return .secondary
        }
    }

    private var pushStatusLabel: String {
        switch pushStatus {
        case .authorized:    return "已开启"
        case .provisional:   return "暂定（不打扰）"
        case .denied:        return "已禁止"
        case .notDetermined: return "未询问"
        case .ephemeral:     return "临时"
        case .unknown:       return "—"
        }
    }

    private func openSystemNotifications() {
        // iOS 16+ exposes `UIApplicationOpenNotificationSettingsURLString`
        // to deep-link straight into the app's notification page in
        // 系统设置. Fallback to the app settings root for older.
        let urlString: String
        if #available(iOS 16.0, *) {
            urlString = UIApplication.openNotificationSettingsURLString
        } else {
            urlString = UIApplication.openSettingsURLString
        }
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

/// TestFlight + dev-only: flip feature flags from the UI without
/// shipping a new build. Hidden from App Store users via
/// `FeatureFlags.isInternalBuild`. Tapping a toggle persists via
/// UserDefaults; "重置为默认值" wipes the override.
private struct FeatureFlagsSection: View {
    @State private var refreshTrigger: Int = 0

    var body: some View {
        Section {
            ForEach(FeatureFlags.Flag.allCases, id: \.rawValue) { flag in
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(flag.displayName, isOn: binding(for: flag))
                        .accessibilityIdentifier("feature_flag_\(flag.rawValue)")
                    Text(flag.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            Button("重置为默认值", role: .destructive) {
                for flag in FeatureFlags.Flag.allCases {
                    FeatureFlags.setOverride(flag, to: nil)
                }
                refreshTrigger &+= 1
            }
            .accessibilityIdentifier("feature_flags_reset")
        } header: {
            Text("功能开关 (内部测试)")
        } footer: {
            Text("仅 TestFlight / 开发安装可见。修改后请回到 Hub 查看效果，部分变化需要重新进入页面才能生效。")
                .font(.caption2)
        }
        .id(refreshTrigger)
    }

    private func binding(for flag: FeatureFlags.Flag) -> Binding<Bool> {
        Binding(
            get: { FeatureFlags.isOn(flag) },
            set: { FeatureFlags.setOverride(flag, to: $0) },
        )
    }
}


private struct AutomationOrderResetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var status: Status = .idle

    let apiService: APIServiceProtocol

    enum Status: Equatable {
        case idle, sending, done, failed(String)
    }

    var body: some View {
        Form {
            Section {
                Button("立即重置排序", role: .destructive) {
                    Task { await reset() }
                }
                .disabled(status == .sending)
            } footer: {
                switch status {
                case .idle:
                    Text("规则将按预设默认顺序展示，自定义拖动顺序会丢失。")
                case .sending:
                    Text("正在重置…")
                case .done:
                    Text("已重置。返回自动化列表查看默认顺序。")
                        .foregroundStyle(.green)
                case .failed(let msg):
                    Text("重置失败：\(msg)")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("重置自定义排序")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reset() async {
        status = .sending
        // Phase D.2 — empty rule_ids + clear=true wipes display_order
        // on every rule for the current user.
        let result = await apiService.reorderAutomations(ruleIds: [], clear: true)
        switch result {
        case .success:
            status = .done
        case .failure(let err):
            status = .failed(err.localizedDescription)
        }
    }
}
