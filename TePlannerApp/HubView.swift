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
    @StateObject private var rulesStore: AutomationRulesStore
    @StateObject private var statsViewModel: ChargingStatsViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let apiService: APIServiceProtocol
    private let authSession: AuthSession
    private let chargingTracker: ChargingSessionTracker
    private let departureStore: ScheduledDepartureStore
    @State private var showingUnbindConfirm = false
    @State private var showingDepartureSheet = false
    @State private var scheduledDeparture: ScheduledDeparture?
    @State private var unbindError: String?
    @State private var alertActionError: String?
    @State private var preheatStatus: PreheatStatus = .idle
    // chargeLimitStatus moved into HubChargeLimitCard's local @State.
    @State private var showingPairingPrompt = false
    @State private var showingSettings = false
    /// First-launch welcome banner: shown until the user dismisses
    /// it the first time. Persisted in SettingsStore.hasSeenHubWelcome.
    @State private var showWelcomeBanner: Bool =
        !UserDefaultsSettingsStore.shared.hasSeenHubWelcome
    /// Phase 6: nil = haven't fetched yet; false = fetched, no
    /// `tel:*:since` rows exist (server hasn't seen any telemetry from
    /// this car). Drives the "等待车辆上线" placeholder.
    @State private var telemetryReady: Bool? = nil
    /// Phase 9 + 10 — the most recent pending / queued command we
    /// surface as a banner. Populated by `refreshCommandStatuses()`
    /// running on the same cadence as automation-state polling.
    @State private var activePending: PendingCommand?
    @State private var activeQueued: QueuedCommand?
    /// Pending banners auto-dismiss ~3s after they reach a terminal
    /// status. We track the timestamp so we don't keep them around
    /// after that window even if the server still returns the row.
    @State private var pendingResolvedAt: Date?
    @Environment(\.openURL) private var openURL

    init(apiService: APIServiceProtocol, authSession: AuthSession) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            apiService: apiService,
            authSession: authSession
        ))
        // Bootstrap with hardcoded PresetSpecs so the engine is ready
        // before the first `/api/v1/automations` fetch lands. As soon
        // as the rulesStore returns, we replace the registry via
        // updateRegistry. If the user is offline / backend is down,
        // the bootstrapped specs keep the engine functional.
        _automationEngine = StateObject(wrappedValue: AutomationEngine(
            registry: PresetSpecs.allPresets,
            apiService: apiService,
            settings: UserDefaultsSettingsStore.shared
        ))
        _rulesStore = StateObject(wrappedValue: AutomationRulesStore(
            apiService: apiService,
            settings: UserDefaultsSettingsStore.shared
        ))
        _statsViewModel = StateObject(wrappedValue: ChargingStatsViewModel())
        self.chargingTracker = ChargingSessionTracker()
        self.departureStore = UserDefaultsScheduledDepartureStore.shared
        self.apiService = apiService
        self.authSession = authSession
    }

    enum PreheatStatus: Equatable {
        case idle, sending, sent, failed(String)
    }

    // ChargeLimitStatus moved into HubChargeLimitCard.Status.

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if showWelcomeBanner {
                    welcomeBanner
                }
                statusCard
                alertPill
                departureCard
                chargeLimitSuggestionCard
                planningEntry
                automationsEntry
                batteryEntry
            }
            .padding(16)
        }
        .navigationTitle("Tautomation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("配对车辆控制", systemImage: "key.fill") {
                        openVCPPairingURL()
                    }
                    Button("设置", systemImage: "gearshape.fill") {
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
            await rulesStore.refresh()
            automationEngine.observe(viewModel.vehicleState, vehicleId: viewModel.vehicle?.id)
            await refreshTelemetryState()
            await refreshCommandStatuses()
            chargingTracker.observe(viewModel.vehicleState, locationName: viewModel.locationName)
            statsViewModel.refresh()
            scheduledDeparture = departureStore.current()
            LocalNotificationScheduler.shared.onPreheatTapped = { @MainActor in
                triggerPreheat()
            }
            // Notification-center inline action: "关闭露营" / "关闭
            // 哨兵" buttons forward through here so AutomationEngine
            // can dispatch the rule's configured primary capability.
            LocalNotificationScheduler.shared.onAlertPrimaryAction = { kindRaw in
                Task { @MainActor in
                    guard let kind = VehicleAlert.Kind(rawValue: kindRaw),
                          let alert = automationEngine.alerts.first(where: { $0.kind == kind })
                    else { return }
                    let result = await automationEngine.performPrimaryAction(
                        for: alert,
                        vehicleId: viewModel.vehicle?.id
                    )
                    if case .failure(let err) = result {
                        alertActionError = err.localizedDescription
                    }
                    await pollCommandStatusesUntilSettled()
                }
            }
            viewModel.startPolling()
            promptVCPPairingIfNeeded()
        }
        .onChange(of: rulesStore.rules) { _, fetched in
            // Keep the engine registry in sync with whatever the
            // backend last returned. If the fetch fails the engine
            // keeps running on the PresetSpecs bootstrap.
            if !fetched.isEmpty {
                automationEngine.updateRegistry(fetched)
            }
        }
        .onDisappear { viewModel.stopPolling() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.startPolling()
                statsViewModel.refresh()
            default: viewModel.stopPolling()
            }
        }
        .onChange(of: viewModel.vehicleState) { _, newState in
            automationEngine.observe(newState, vehicleId: viewModel.vehicle?.id)
            chargingTracker.observe(newState, locationName: viewModel.locationName)
            statsViewModel.refresh()
            promptVCPPairingIfNeeded()
            Task {
                await refreshTelemetryState()
                await refreshCommandStatuses()
            }
        }
        .onChange(of: automationEngine.alerts) { _, alerts in
            LocalNotificationScheduler.shared.applyAlerts(alerts)
        }
        .sheet(isPresented: $showingDepartureSheet) {
            ScheduledDepartureSheet(
                existing: scheduledDeparture,
                vehicleId: viewModel.vehicle?.id,
                onSave: { entry in
                    departureStore.save(entry)
                    scheduledDeparture = entry
                    LocalNotificationScheduler.shared.schedulePreheat(for: entry)
                    Log.app.notice("departure saved at \(entry.departureAt, privacy: .public)")
                },
                onClear: scheduledDeparture == nil ? nil : {
                    departureStore.clear()
                    scheduledDeparture = nil
                    LocalNotificationScheduler.shared.cancelPreheat()
                    Log.app.notice("departure cleared")
                }
            )
        }
        .confirmationDialog(
            "解绑 Tesla 账户",
            isPresented: $showingUnbindConfirm,
            titleVisibility: .visible
        ) {
            // Destructive button text avoids the substring "解绑" alone
            // because the menu item that triggers this dialog is also
            // "解绑 Tesla 账户" — Maestro's substring matcher would
            // otherwise race the menu's dismiss animation against the
            // dialog's appearance and pick the wrong element.
            Button("确认解绑", role: .destructive) {
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
        .sheet(isPresented: $showingSettings) {
            SettingsView(apiService: apiService)
        }
        .alert("配对车辆控制", isPresented: $showingPairingPrompt) {
            Button("立即配对") {
                openVCPPairingURL()
                // openVCPPairingURL already sets the flag, but be
                // belt-and-suspenders here.
                UserDefaultsSettingsStore.shared.hasPromptedVCPPairing = true
            }
            Button("稍后再说", role: .cancel) {
                // Mark prompted regardless of choice — otherwise the
                // dialog re-fires on every hub return. Users who
                // want to pair later have a permanent menu entry.
                UserDefaultsSettingsStore.shared.hasPromptedVCPPairing = true
            }
        } message: {
            Text("为了让 Tautomation 能直接调用车辆命令（关闭露营 / 启动空调预热 / 调整充电限额等），需要你在 Tesla 官方 App 中授权一次。点击「立即配对」会打开 Tesla App 完成。可在右上角菜单 → 配对车辆控制 重新打开。")
        }
    }

    /// Pull the latest server-recorded `tel:<entity>:since` timestamps
    /// and seed the engine memory. Errors are swallowed — a failed
    /// fetch just means the rule keeps its locally-observed start time
    /// (current behavior for offline / pre-Phase-5 builds).
    ///
    /// Phase 6: also flips `telemetryReady` based on whether the server
    /// has any `tel:*:since` rows for this vehicle. Until it does, the
    /// hub surfaces a "等待车辆上线" placeholder explaining the empty
    /// automation state.
    private func refreshTelemetryState() async {
        switch await apiService.fetchAutomationState() {
        case .success(let resp):
            await MainActor.run {
                automationEngine.applyServerTelemetryState(resp.entries)
                telemetryReady = !resp.entries.isEmpty
            }
        case .failure(let err):
            Log.api.debug("fetchAutomationState skipped: \(err.localizedDescription, privacy: .public)")
        }
    }

    /// Phase 9 + 10 — poll command status. Runs alongside
    /// `refreshTelemetryState` on the same cadence as the rest of the
    /// hub.  We pick the freshest row of each type to drive the
    /// banner. Pending banners auto-dismiss ~3 s after reaching a
    /// terminal state so the hub returns to its idle layout.
    private func refreshCommandStatuses() async {
        async let pendingResp = apiService.fetchPendingCommands()
        async let queuedResp = apiService.fetchQueuedCommands()
        let (p, q) = await (pendingResp, queuedResp)

        await MainActor.run {
            // -- Pending: show the most recently dispatched row.
            if case .success(let resp) = p, let latest = resp.pending.first {
                let isResolved = latest.status != "pending"
                let resolvedAt = pendingResolvedAt
                if isResolved && resolvedAt == nil {
                    pendingResolvedAt = Date()
                }
                if isResolved, let ts = pendingResolvedAt,
                   Date().timeIntervalSince(ts) > 3 {
                    activePending = nil
                    pendingResolvedAt = nil
                } else {
                    activePending = latest
                    if !isResolved { pendingResolvedAt = nil }
                }
            } else {
                activePending = nil
                pendingResolvedAt = nil
            }

            // -- Queued: surface the most recent row that's actually
            // worth showing (sent rows older than 30s vanish — the
            // confirmation pill takes over from there).
            if case .success(let resp) = q {
                let row = resp.queued.first { row in
                    if row.status == "queued" { return true }
                    // brief afterglow on resolution so user sees it
                    let resolvedAt = row.sentAt ?? row.droppedAt
                    if let resolvedAt {
                        return Date().timeIntervalSince(resolvedAt) < 5
                    }
                    return false
                }
                activeQueued = row
            }
        }
    }

    private func cancelQueued(_ id: Int) async {
        _ = await apiService.cancelQueuedCommand(id: id)
        await refreshCommandStatuses()
    }

    /// After dispatching a VCP command we want the banner to flip
    /// "正在关闭…" → "已关闭" within a second of the car producing
    /// confirming telemetry. Poll on a 1 s cadence for up to ~12 s
    /// (roughly one debounce window past the resolver's 60 s timeout
    /// is overkill; 12 s catches the realistic happy-path latency).
    private func pollCommandStatusesUntilSettled() async {
        let deadline = Date().addingTimeInterval(12)
        await refreshCommandStatuses()
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await refreshCommandStatuses()
            // Stop early once we've shown a terminal status.
            if let p = activePending, p.status != "pending" { break }
        }
    }

    private func openVCPPairingURL() {
        // tesla.com/_ak/<domain> 是 Tesla 官方支持的 partner-key
        // 配对深链。在已装 Tesla App 的手机上点开会唤起 App，让用户
        // 一次性授权我们的 partner public key（来自
        // https://api.teplanner.cloud/.well-known/appspecific/com.tesla.3p.public-key.pem）。
        guard let url = URL(string: "https://tesla.com/_ak/api.teplanner.cloud") else { return }
        Log.app.notice("open VCP pairing deep-link")
        openURL(url)
        UserDefaultsSettingsStore.shared.hasPromptedVCPPairing = true
    }

    private func promptVCPPairingIfNeeded() {
        guard !UserDefaultsSettingsStore.shared.hasPromptedVCPPairing else { return }
        // Wait until we know the user actually has a Tesla vehicle
        // before nagging — no point prompting before OAuth completes.
        guard viewModel.vehicle != nil else { return }
        showingPairingPrompt = true
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.displayName ?? "我的 Tesla")
                    .font(.title3.weight(.semibold))
                Spacer()
                stateBadge
            }
            HStack(alignment: .center, spacing: 24) {
                batteryRing
                VStack(alignment: .leading, spacing: 2) {
                    if let range = viewModel.batteryRangeKm {
                        Text("\(Int(range))")
                            .font(.system(size: 44, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                        Text("km 续航")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("续航未知")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

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
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("hub_status_card")
    }

    private var batteryRing: some View {
        let knownLevel = viewModel.batteryLevel
        let level = knownLevel ?? 0
        let progress = Double(max(0, min(100, level))) / 100.0
        // While loading we don't know the SOC yet — drawing a 0%
        // empty ring + 'red' tint reads as 'battery dead'. Render a
        // dimmed placeholder ring + '— %' instead.
        let isUnknown = knownLevel == nil
        return ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 10)
            if !isUnknown {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        batteryColor(for: level),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: level)
            }
            VStack(spacing: 0) {
                Text(isUnknown ? "—" : "\(level)%")
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundStyle(isUnknown ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                Image(systemName: isUnknown ? "battery.50" : batteryIcon)
                    .font(.caption)
                    .foregroundStyle(isUnknown ? AnyShapeStyle(.tertiary) : AnyShapeStyle(batteryColor(for: level)))
            }
        }
        .frame(width: 92, height: 92)
        .accessibilityIdentifier("hub_battery_ring")
        .accessibilityLabel(isUnknown ? "电量加载中" : "电量 \(level) 百分")
    }

    private func batteryColor(for level: Int) -> Color {
        switch level {
        case ..<20: return .red
        case ..<50: return .orange
        case ..<80: return .accentColor
        default: return .green
        }
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

    // chargeLimit* moved to TePlannerApp/HubChargeLimitCard.swift —
    // wrap the constructor in a computed view to keep the parent
    // VStack's type-inference cheap.
    private var chargeLimitSuggestionCard: some View {
        HubChargeLimitCard(
            currentLimit: viewModel.vehicleState?.chargeLimitSoc,
            scheduledDeparture: scheduledDeparture,
            vehicleId: viewModel.vehicle?.id,
            apiService: apiService,
            onApplied: { Task { await viewModel.refresh() } },
            onError: { msg in alertActionError = msg },
        )
    }

    @ViewBuilder
    private var departureCard: some View {
        Button {
            showingDepartureSheet = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "alarm.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    if let scheduled = scheduledDeparture {
                        Text(formatDeparture(scheduled.departureAt))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(departureSubtitle(scheduled))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("下次出行")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("设置出发时间，出发前自动提醒预热")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                preheatBadge
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardButtonStyle())
        .accessibilityIdentifier("hub_departure_card")
    }

    @ViewBuilder
    private var preheatBadge: some View {
        switch preheatStatus {
        case .idle:
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        case .sending:
            ProgressView().controlSize(.small)
        case .sent:
            Label("已启动", systemImage: "checkmark.circle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.green)
        case .failed:
            Label("失败", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
        }
    }

    private func departureSubtitle(_ departure: ScheduledDeparture) -> String {
        let interval = departure.departureAt.timeIntervalSinceNow
        if interval <= 0 { return "出发时间已到" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "还有 \(minutes) 分钟 · 提前 \(departure.leadTimeMinutes) 分钟提醒" }
        let h = minutes / 60
        let m = minutes % 60
        let countdown = m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分"
        return "还有 \(countdown) · 提前 \(departure.leadTimeMinutes) 分钟提醒"
    }

    private func formatDeparture(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: date)
    }

    private func triggerPreheat() {
        guard let vehicleId = viewModel.vehicle?.id else { return }
        guard preheatStatus != .sending else { return }
        preheatStatus = .sending
        Task {
            let result = await apiService.preheat(vehicleId: vehicleId)
            switch result {
            case .success:
                preheatStatus = .sent
                Log.vehicle.notice("preheat OK")
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                if case .sent = preheatStatus { preheatStatus = .idle }
            case .failure(let err):
                preheatStatus = .failed(err.localizedDescription)
                Log.vehicle.error("preheat failed: \(err.localizedDescription, privacy: .public)")
                alertActionError = err.localizedDescription
                try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
                if case .failed = preheatStatus { preheatStatus = .idle }
            }
        }
    }

    /// First-launch welcome banner — explains what the app does +
    /// how to dismiss. Auto-hides after first dismiss; reset via
    /// "重置" if we ever add it. Inspired by Shortcuts' first-run
    /// "Get Started" card.
    private var welcomeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                    .font(.title3)
                Text("欢迎使用 Tautomation")
                    .font(.headline)
                Spacer()
                Button {
                    UserDefaultsSettingsStore.shared.hasSeenHubWelcome = true
                    withAnimation { showWelcomeBanner = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("welcome_banner_dismiss")
            }
            Text("已为你预设 8 条常用自动化提醒——露营超时、忘锁车、充电完成等。在「自动化」中可逐条查看、调整或新增。")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label("Telemetry 实时车况", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label("地理围栏", systemImage: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label("一键执行", systemImage: "hand.tap.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
        .accessibilityIdentifier("hub_welcome_banner")
    }

    @ViewBuilder
    private var alertPill: some View {
        ZStack {
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
                        // Phase 9 — start a quick-poll burst so the user
                        // sees "正在关闭…" within a second of the tap.
                        await pollCommandStatusesUntilSettled()
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .opacity,
                ))
            } else if telemetryReady == false && shouldShowTelemetryWaiting {
                telemetryWaitingPill
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: automationEngine.alerts.first?.kind)
        commandStatusBanner
    }

    /// Suppress the "等待车辆推送" placeholder when the status card
    /// already shows the car is online — otherwise users see two
    /// contradictory signals on the same screen. We keep the pill for
    /// the genuine cold-start case (no telemetry rows AND vehicle
    /// reports offline / unknown).
    private var shouldShowTelemetryWaiting: Bool {
        switch viewModel.state {
        case .ready: return false
        default: return true
        }
    }

    /// Phase 9 + 10 — only shown when there is something to surface;
    /// stays out of the way otherwise (idle hub looks identical to
    /// before).
    @ViewBuilder
    private var commandStatusBanner: some View {
        if activePending != nil || activeQueued != nil {
            CommandStatusBanner(
                pending: activePending,
                queued: activeQueued,
                onCancelQueued: { id in
                    Task { await cancelQueued(id) }
                }
            )
        }
    }

    /// Phase 6: shown when `/api/v1/automations/state` returns zero
    /// telemetry-since entries — i.e. the car hasn't pushed any state
    /// changes to our server yet (typical right after VCP pairing or
    /// after the first install). Once the car comes online, the next
    /// state change writes a `tel:*:since` row and the pill flips to
    /// the regular alert pill content.
    private var telemetryWaitingPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("自动化即将激活")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("当你的车下次开门、移动或充电时，提醒会自动开始工作。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("telemetry_waiting_pill")
    }

    private var planningEntry: some View {
        NavigationLink {
            MapHomeView(apiService: apiService, viewModel: viewModel)
        } label: {
            HubEntryCard(
                icon: "bolt.fill",
                title: "充电规划",
                subtitle: "搜目的地 / 沿途充电站 / 发送到车辆",
                accessibilityId: "hub_entry_planning"
            )
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    private var automationsEntry: some View {
        NavigationLink {
            AutomationsHomeView(rulesStore: rulesStore, apiService: apiService)
        } label: {
            HubEntryCard(
                icon: "bell.badge.fill",
                title: "自动化",
                subtitle: automationsSubtitle,
                accessibilityId: "hub_entry_automations"
            )
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    private var batteryEntry: some View {
        NavigationLink {
            BatteryView(
                apiService: apiService,
                vehicleId: viewModel.vehicle?.id,
                currentChargeLimitSoc: viewModel.vehicleState?.chargeLimitSoc,
                onLimitApplied: { Task { await viewModel.refresh() } }
            )
        } label: {
            HubEntryCard(
                icon: "battery.100.bolt",
                title: "电池管理",
                subtitle: batterySubtitle,
                accessibilityId: "hub_entry_battery"
            )
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    private var batterySubtitle: String {
        let state = viewModel.vehicleState?.chargingState
        let limit = viewModel.vehicleState?.chargeLimitSoc
        let level = viewModel.batteryLevel
        switch state {
        case "Charging":
            if let l = limit { return "充电中 · 上限 \(l)%" }
            return "充电中"
        case "Complete":
            if let l = limit { return "已充满 · 上限 \(l)%" }
            return "已充满"
        case "Disconnected", "NoPower":
            if let lvl = level, let l = limit { return "电量 \(lvl)% · 上限 \(l)%" }
            if let l = limit { return "未连接充电桩 · 上限 \(l)%" }
            return "未连接充电桩"
        default:
            var parts: [String] = []
            if let l = limit { parts.append("上限 \(l)%") }
            if statsViewModel.hasAnyData {
                parts.append("本月 \(statsViewModel.monthlyCount) 次")
            }
            return parts.isEmpty ? "充电限额 / 统计 / 历史" : parts.joined(separator: " · ")
        }
    }

    /// Look up the rule name that produced this alert (alert.kind →
    /// rule.spec.kind match). Falls back to the alert title if no
    /// matching rule is found, so the auto card can always show
    /// _something_ informative.
    private func firingRuleName(for alert: VehicleAlert) -> String {
        if let rule = rulesStore.rules.first(where: {
            $0.spec.string("kind") == alert.kind.rawValue
        }) {
            return rule.name
        }
        return alert.title
    }

    /// Subtitle for the automation entry card. Goal: tell the user
    /// what the rules actually do, not a counter that requires
    /// drilling in to make sense of. Show 2 representative rule names
    /// + count when collapsed; "已全部禁用" when none firing.
    private var automationsSubtitle: String {
        let rules = rulesStore.rules
        let total = rules.count
        let enabled = rules.filter(\.enabled)
        if total == 0 { return "暂无规则" }
        if enabled.isEmpty { return "全部已禁用，点击启用" }
        // If any rule is actively firing right now, lead with that —
        // it's the highest-signal info ("there's something to look at").
        // Name the rule(s) so users don't have to guess which one. The
        // top alert is also surfaced as the alert pill above; this row
        // doubles as a shortcut to the matching rule.
        let alerts = automationEngine.alerts
        if !alerts.isEmpty {
            let names = alerts.prefix(2).map { firingRuleName(for: $0) }.joined(separator: " · ")
            if alerts.count > 2 {
                return "⚠️ \(names) · 共 \(alerts.count) 条触发中"
            }
            return "⚠️ 触发中：\(names)"
        }
        // Snoozed count shown when no fires — gives the user a passive
        // reminder that some rules are temporarily muted.
        let snoozed = UserDefaultsSettingsStore.shared.ruleSnooze.count
        if snoozed > 0 {
            return "🔕 \(snoozed) 条静音中 · 共 \(enabled.count) 条启用"
        }
        // Otherwise show the 2 most representative names + count.
        let preview = enabled.prefix(2).map(\.name).joined(separator: " · ")
        if enabled.count > 2 {
            return "\(preview) · 共 \(enabled.count) 条"
        }
        return preview
    }
}

/// Subtle scale + dim on press. Replaces `.buttonStyle(.plain)` which
/// disables press feedback entirely and leaves Hub cards feeling dead
/// to taps. Spring is intentionally short so the response feels
/// instant rather than bouncy.
struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: configuration.isPressed)
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
