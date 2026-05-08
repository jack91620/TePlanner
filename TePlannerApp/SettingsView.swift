import SwiftUI
import TePlannerKit

/// 设置页 — 偏好、关于、调试入口。Reachable from the hub menu.
/// Intentionally short for v1: the app's automation settings live
/// per-rule, this is the place for cross-cutting prefs.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let appVersion: String
    private let buildNumber: String

    init() {
        let info = Bundle.main.infoDictionary
        self.appVersion = info?["CFBundleShortVersionString"] as? String ?? "0.0"
        self.buildNumber = info?["CFBundleVersion"] as? String ?? "0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                } header: {
                    Text("通知")
                } footer: {
                    Text("Tautomation 通过系统通知中心推送自动化提醒。可在系统设置里调整声音、横幅样式等。")
                }

                Section {
                    NavigationLink {
                        AutomationOrderResetView()
                    } label: {
                        Label("重置自定义排序", systemImage: "arrow.up.arrow.down")
                    }
                } header: {
                    Text("自动化")
                } footer: {
                    Text("将自动化列表恢复为默认顺序。规则本身不会受影响。")
                }

                Section {
                    LabeledContent("版本", value: "\(appVersion) (\(buildNumber))")
                    LabeledContent("构建", value: "Tautomation iOS")
                    Link(destination: URL(string: "https://api.teplanner.cloud")!) {
                        Label("后端服务状态", systemImage: "server.rack")
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
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

private struct AutomationOrderResetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var done = false

    var body: some View {
        Form {
            Section {
                Button("立即重置排序", role: .destructive) {
                    UserDefaultsSettingsStore.shared.automationRuleOrder = []
                    done = true
                }
            } footer: {
                if done {
                    Text("已重置。返回自动化列表查看默认顺序。")
                        .foregroundStyle(.green)
                } else {
                    Text("规则将按预设默认顺序展示，自定义拖动顺序会丢失。")
                }
            }
        }
        .navigationTitle("重置自定义排序")
        .navigationBarTitleDisplayMode(.inline)
    }
}
