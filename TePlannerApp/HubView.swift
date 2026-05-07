import SwiftUI
import TePlannerKit

/// App 主页 (Hub)：参考 Tesla 官方 App 的入口式布局——顶部车辆状态卡，
/// 下方一列功能入口（充电规划 / 自动化提醒 / 充电统计）。Alert pill
/// 在 hub 上方显示，让用户一开 App 就能看到 critical 提醒。
///
/// 这一层 own 整个 session 的核心状态：
/// - `HomeViewModel`：车辆状态 + polling
/// - `AutomationEngine`：规则求值 + 通知调度
///
/// 子页（MapHomeView 等）通过 NavigationLink push，并以 `@ObservedObject`
/// 接收同一份 ViewModel/Engine 引用，避免下钻时丢状态、重复 polling。
struct HubView: View {
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var automationEngine: AutomationEngine
    @Environment(\.scenePhase) private var scenePhase
    private let apiService: APIServiceProtocol
    private let authSession: AuthSession
    @State private var showingSettings = false
    @State private var showingUnbindConfirm = false
    @State private var unbindError: String?
    @State private var alertActionError: String?

    init(apiService: APIServiceProtocol, authSession: AuthSession) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            apiService: apiService,
            authSession: authSession
        ))
        _automationEngine = StateObject(wrappedValue: AutomationEngine(
            registry: [
                CampModeAutomation(),
                SentryModeAutomation(),
                CabinOverheatAutomation(),
                ChargeCompleteAutomation(),
            ],
            apiService: apiService,
            settings: UserDefaultsSettingsStore.shared
        ))
        self.apiService = apiService
        self.authSession = authSession
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusCard
                if let alert = automationEngine.alerts.first {
                    AlertPillView(alert: alert) {
                        Task {
                            let result = await automationEngine.performPrimaryAction(
                                for: alert,
                                vehicleId: viewModel.vehicle?.id
                            )
                            if case .failure(let err) = result {
                                alertActionError = err.localizedDescription
                            }
                        }
                    }
                }
                NavigationLink {
                    MapHomeView(
                        apiService: apiService,
                        viewModel: viewModel,
                        automationEngine: automationEngine
                    )
                } label: {
                    HubEntryCard(
                        icon: "bolt.fill",
                        title: "充电规划",
                        subtitle: "搜目的地 / 沿途充电站 / 发送到车辆",
                        accessibilityId: "hub_entry_planning"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AutomationsListView(
                        rules: automationEngine.registeredRules,
                        store: UserDefaultsSettingsStore.shared
                    )
                } label: {
                    HubEntryCard(
                        icon: "bell.badge.fill",
                        title: "自动化提醒",
                        subtitle: automationsSubtitle,
                        accessibilityId: "hub_entry_automations"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ChargingStatsView()
                } label: {
                    HubEntryCard(
                        icon: "chart.bar.fill",
                        title: "充电统计",
                        subtitle: "敬请期待",
                        accessibilityId: "hub_entry_stats"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .navigationTitle("TePlanner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("设置", systemImage: "gearshape") {
                        showingSettings = true
                    }
                    Divider()
                    Button("退出登录", systemImage: "arrow.right.square", role: .destructive) {
                        authSession.logout()
                    }
                    Button("解绑 Tesla 账户", systemImage: "link.badge.plus", role: .destructive) {
                        showingUnbindConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("hub_menu_button")
            }
        }
        .task {
            await viewModel.load()
            automationEngine.observe(viewModel.vehicleState, vehicleId: viewModel.vehicle?.id)
            viewModel.startPolling()
        }
        .onDisappear { viewModel.stopPolling() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: viewModel.startPolling()
            default: viewModel.stopPolling()
            }
        }
        .onChange(of: viewModel.vehicleState) { _, newState in
            automationEngine.observe(newState, vehicleId: viewModel.vehicle?.id)
        }
        .onChange(of: automationEngine.alerts) { _, alerts in
            LocalNotificationScheduler.shared.applyAlerts(alerts)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "解绑 Tesla 账户",
            isPresented: $showingUnbindConfirm,
            titleVisibility: .visible
        ) {
            Button("解绑", role: .destructive) {
                Task {
                    let result = await authSession.unbindTesla(api: apiService)
                    if case .failure(let err) = result {
                        unbindError = err.localizedDescription
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将清除服务端授权与本地凭据，下次登录需要重新授权 Tesla。")
        }
        .alert("解绑失败", isPresented: Binding(
            get: { unbindError != nil },
            set: { if !$0 { unbindError = nil } }
        )) {
            Button("好") { unbindError = nil }
        } message: {
            Text(unbindError ?? "")
        }
        .alert("操作失败", isPresented: Binding(
            get: { alertActionError != nil },
            set: { if !$0 { alertActionError = nil } }
        )) {
            Button("好") { alertActionError = nil }
        } message: {
            Text(alertActionError ?? "")
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.displayName ?? "我的 Tesla")
                    .font(.title3.weight(.semibold))
                Spacer()
                stateBadge
            }
            HStack(spacing: 18) {
                Label {
                    Text("\(viewModel.batteryLevel ?? 0)%")
                } icon: {
                    Image(systemName: batteryIcon)
                        .foregroundStyle(.tint)
                }
                if let range = viewModel.batteryRangeKm {
                    Label("\(Int(range)) km", systemImage: "road.lanes")
                }
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)

            if let location = viewModel.locationName {
                Label {
                    Text(location).lineLimit(2)
                } icon: {
                    Image(systemName: "location.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("hub_status_card")
    }

    private var batteryIcon: String {
        let level = viewModel.batteryLevel ?? 0
        switch level {
        case ..<20: return "battery.0"
        case ..<50: return "battery.25"
        case ..<80: return "battery.75"
        default: return "battery.100"
        }
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView().controlSize(.small)
        case .waking(let attempt, let max):
            Label("唤醒中 \(attempt)/\(max)", systemImage: "moon.zzz")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        case .ready:
            Label(chargingLabel, systemImage: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        case .offline:
            Label("离线", systemImage: "circle.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.gray)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    private var chargingLabel: String {
        switch viewModel.chargingState {
        case "Charging": return "充电中"
        case "Complete": return "充电完成"
        case "Disconnected": return "在线"
        default: return "在线"
        }
    }

    /// "X 条已启用" — count rules whose threshold settings are non-zero
    /// (or for the toggle-only rule, whose enabled flag is true).
    private var automationsSubtitle: String {
        let store = UserDefaultsSettingsStore.shared
        let enabled = automationEngine.registeredRules.filter { rule in
            switch rule.kind {
            case .campMode: return store.campModeReminderMinutes > 0
            case .sentryMode: return store.sentryReminderMinutes > 0
            case .cabinOverheat: return store.cabinOverheatReminderMinutes > 0
            case .chargeComplete: return store.chargeCompleteReminderEnabled
            }
        }.count
        return "\(enabled)/\(automationEngine.registeredRules.count) 条已启用"
    }
}

private struct HubEntryCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accessibilityId: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .accessibilityIdentifier(accessibilityId)
    }
}
