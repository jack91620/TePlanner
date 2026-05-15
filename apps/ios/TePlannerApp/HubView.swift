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
    @StateObject private var snoozeStore: BackendSnoozeStore
    @StateObject private var departureStore: BackendScheduledDepartureStore
    @StateObject private var chargingSessionStore: BackendChargingSessionStore
    @StateObject private var commandStatusStore: CommandStatusStore
    @StateObject private var quickActionsStore: HubActionsStore
    @StateObject private var activeTripStore: ActiveTripStore
    @Environment(\.scenePhase) private var scenePhase
    private let apiService: APIServiceProtocol
    private let authSession: AuthSession
    private let chargingTracker: ChargingSessionTracker
    @State private var showingUnbindConfirm = false
    @State private var showingDepartureSheet = false
    @State private var scheduledDeparture: ScheduledDeparture?
    @State private var unbindError: String?
    @State private var alertActionError: String?
    @State private var preheatStatus: PreheatStatus = .idle
    // chargeLimitStatus moved into HubChargeLimitCard's local @State.
    @State private var showingPairingPrompt = false
    @State private var showingSettings = false
    @State private var showingImportShare = false
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
    // 2026-05-11 B2: activePending / activeQueued / pendingResolvedAt
    // moved to the shared CommandStatusStore so dispatchers in other
    // views (BatteryView, HubChargeLimitCard, etc.) can also drive
    // the converge poll without re-implementing the logic.
    /// Set when the user dismisses the "通知未开启" banner — re-shown
    /// after this date passes. Persisted across launches via the
    /// `hideNotificationBannerUntil` UserDefaults key.
    @State private var notificationBannerHideUntil: Date? =
        UserDefaultsSettingsStore.shared.hideNotificationBannerUntil
    @ObservedObject private var notificationScheduler = LocalNotificationScheduler.shared

    /// 2026-05-11 — chip → tap → confirm dialog state. Holds the
    /// chip whose action is awaiting user confirmation. nil = no
    /// dialog showing.
    @State private var pendingChipAction: StatusChip?
    @State private var chipCommandStatus: ChipCommandStatus = .idle

    enum ChipCommandStatus: Equatable {
        case idle
        case sending(label: String)
        case sent(label: String)
        case failed(message: String)
    }

    @Environment(\.openURL) private var openURL

    init(apiService: APIServiceProtocol, authSession: AuthSession) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            apiService: apiService,
            authSession: authSession
        ))
        let snoozeStore = BackendSnoozeStore(apiService: apiService)
        _snoozeStore = StateObject(wrappedValue: snoozeStore)
        // Phase D.6 — engine no longer evaluates rules locally; backend
        // is the single evaluator. Empty registry at boot; rulesStore
        // populates via /automations/. Alerts are fed by APNs +
        // (future) GET /automations/active-alerts via applyServerAlerts.
        _automationEngine = StateObject(wrappedValue: AutomationEngine(
            registry: [],
            apiService: apiService,
            settings: UserDefaultsSettingsStore.shared,
            snoozes: snoozeStore
        ))
        _rulesStore = StateObject(wrappedValue: AutomationRulesStore(
            apiService: apiService,
            settings: UserDefaultsSettingsStore.shared
        ))
        let chargingSessionStore = BackendChargingSessionStore(apiService: apiService)
        _chargingSessionStore = StateObject(wrappedValue: chargingSessionStore)
        _commandStatusStore = StateObject(wrappedValue: CommandStatusStore(apiService: apiService))
        _quickActionsStore = StateObject(wrappedValue: HubActionsStore(apiService: apiService))
        _activeTripStore = StateObject(wrappedValue: ActiveTripStore(apiService: apiService))
        _statsViewModel = StateObject(wrappedValue: ChargingStatsViewModel(store: chargingSessionStore))
        _departureStore = StateObject(wrappedValue: BackendScheduledDepartureStore(apiService: apiService))
        self.chargingTracker = ChargingSessionTracker(store: chargingSessionStore)
        self.apiService = apiService
        self.authSession = authSession
    }

    typealias PreheatStatus = HubDepartureCard.PreheatStatus

    // ChargeLimitStatus moved into HubChargeLimitCard.Status.

    var body: some View {
        scrollContent
        .navigationTitle("Tautomation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("配对车辆控制", systemImage: "key.fill") {
                        openVCPPairingURL()
                    }
                    Button("导入分享码", systemImage: "square.and.arrow.down") {
                        showingImportShare = true
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
            // Kick Quick Actions load FIRST + in the background. The
            // section is one of the most-tapped surfaces on Hub and
            // its data lives in user_settings, independent of Tesla
            // state — no reason to gate it behind vehicle.load() which
            // can take 30s on a sleeping car. Running it as a detached
            // child task lets the UI render the seeded grid within
            // a couple hundred ms even while the status card is still
            // "连接中". Caught by e2e 07 hitting 8 empty slots
            // intermittently when the sim's Tesla session was cold.
            async let qaLoad: Void = quickActionsStore.load()
            async let tripLoad: Void = activeTripStore.refresh()
            await viewModel.load()
            await rulesStore.refresh()
            await snoozeStore.refresh()
            automationEngine.observe(viewModel.vehicleState, vehicleId: viewModel.vehicle?.id)
            await refreshTelemetryState()
            await refreshCommandStatuses()
            chargingTracker.observe(viewModel.vehicleState, locationName: viewModel.locationName)
            await statsViewModel.refresh(vehicleId: viewModel.vehicle?.id)
            await departureStore.refresh()
            scheduledDeparture = departureStore.current()
            await qaLoad
            await tripLoad
            LocalNotificationScheduler.shared.onPreheatTapped = { @MainActor in
                triggerPreheat()
            }
            // 2026-05-11 — `onAlertPrimaryAction` wiring removed.
            // Car-control actions (关闭露营 / 关闭哨兵 / 锁车 / 立即
            // 预热) live on Hub status chips now, behind a tap-to-
            // confirm dialog with live state visible. Notification
            // taps just open the app.
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
            // Reconcile delivered local notifications against the
            // server's `is_firing` set so old banners (from a previous
            // app session, or pre-fix spam runs) get withdrawn from
            // the system tray when the rule is no longer firing.
            var firing: Set<String> = []
            for rule in fetched where rule.isFiring {
                if let k = rule.spec.string("kind") { firing.insert(k) }
                // wait_for_state rules can fire a different alert kind
                // (rule.spec.actions[0].then.kind, default "waitResolved")
                // than the rule's primary spec.kind. Without this both
                // kinds need to be considered "firing" for reconcile or
                // the wait-resolved local notif gets removed immediately.
                for thenKind in waitResolvedKinds(in: rule.spec) {
                    firing.insert(thenKind)
                }
            }
            LocalNotificationScheduler.shared.reconcileDelivered(firingKinds: firing)
        }
        .onDisappear { viewModel.stopPolling() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.startPolling()
                // Refresh on every foreground so any silent drift
                // (e.g. toggle PATCH succeeded but client got network
                // error and didn't realize, or server-side seeding
                // added a new preset, or another device changed state)
                // converges within seconds of the user opening the app.
                Task {
                    await rulesStore.refresh()
                    await statsViewModel.refresh(vehicleId: viewModel.vehicle?.id)
                }
                // Pick up notification permission changes the user
                // made in iOS Settings while the app was background.
                notificationScheduler.refreshAuthStatus()
            default: viewModel.stopPolling()
            }
        }
        .onChange(of: viewModel.vehicleState) { _, newState in
            automationEngine.observe(newState, vehicleId: viewModel.vehicle?.id)
            chargingTracker.observe(newState, locationName: viewModel.locationName)
            // Phase D.4 — store auto-refreshes on its own changes;
            // statsViewModel reload is driven by changesPublisher.
            promptVCPPairingIfNeeded()
            Task {
                await refreshTelemetryState()
                await refreshCommandStatuses()
            }
        }
        .onChange(of: automationEngine.alerts) { _, alerts in
            LocalNotificationScheduler.shared.applyAlerts(alerts)
        }
        .onReceive(departureStore.changesPublisher) { _ in
            // Backend refresh / save / clear flowed back — re-derive
            // the UI's @State copy. The local notification scheduler
            // is driven from the same source of truth.
            scheduledDeparture = departureStore.current()
        }
        .sheet(isPresented: $showingDepartureSheet) {
            ScheduledDepartureSheet(
                existing: scheduledDeparture,
                vehicleId: viewModel.vehicle?.id,
                onSave: { entry in
                    Task {
                        let ok = await departureStore.save(entry)
                        if ok {
                            scheduledDeparture = departureStore.current()
                            LocalNotificationScheduler.shared.schedulePreheat(for: entry)
                            Log.app.notice("departure saved at \(entry.departureAt, privacy: .public)")
                        } else {
                            alertActionError = "出行计划保存失败，请稍后重试"
                        }
                    }
                },
                onClear: scheduledDeparture == nil ? nil : {
                    Task {
                        let ok = await departureStore.clear()
                        if ok {
                            scheduledDeparture = nil
                            LocalNotificationScheduler.shared.cancelPreheat()
                            Log.app.notice("departure cleared")
                        } else {
                            alertActionError = "出行计划清除失败，请稍后重试"
                        }
                    }
                }
            )
        }
        .alert(
            "解绑 Tesla 账户",
            isPresented: $showingUnbindConfirm
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
        .sheet(isPresented: $showingImportShare) {
            ImportShareSheet(
                hubStore: quickActionsStore,
                rulesStore: rulesStore,
                onDismiss: { showingImportShare = false },
            )
        }
        .alert(
            pendingChipAction?.confirmTitle ?? "",
            isPresented: Binding(
                get: { pendingChipAction != nil },
                set: { if !$0 { pendingChipAction = nil } }
            )
        ) {
            if let chip = pendingChipAction {
                Button(chip.label.contains("锁") ? "锁车" : "确认", role: .destructive) {
                    let action = chip.action
                    pendingChipAction = nil
                    Task { await action?() }
                }
                Button("取消", role: .cancel) { pendingChipAction = nil }
            }
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
    /// All AlertKinds a rule's wait_for_state then-action could fire.
    /// Currently at most one (v1 wait_resolver), but returned as Set
    /// so caller can union without special-casing the empty case.
    private func waitResolvedKinds(in spec: RuleSpec) -> Set<String> {
        var out: Set<String> = []
        for bucket in ["actions", "actions_above", "actions_below"] {
            guard let arr = spec[bucket]?.arrayValue else { continue }
            for action in arr {
                guard let obj = action.objectValue,
                      obj.string("type") == "wait_for_state",
                      let then = obj["then"]?.objectValue else { continue }
                out.insert(then.string("kind") ?? "waitResolved")
            }
        }
        return out
    }

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
    // 2026-05-11 B2: refresh + poll-until-settled now live on the
    // shared CommandStatusStore; HubView observes via the @StateObject.
    // Other dispatchers (BatteryView, HubChargeLimitCard, etc.) inject
    // the same store and call store.pollUntilSettled() after their own
    // VCP-commit calls — keeping the banner converging consistently
    // regardless of which view dispatched.
    private func refreshCommandStatuses() async {
        await commandStatusStore.refresh()
    }

    private func pollCommandStatusesUntilSettled() async {
        await commandStatusStore.pollUntilSettled()
    }

    private func cancelQueued(_ id: Int) async {
        await commandStatusStore.cancelQueued(id: id)
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

    /// Extracted from `body` so the type-checker stays under budget.
    /// SwiftUI couldn't infer the opaque `some View` type with all
    /// 8+ children + the conditional welcome banner inline.
    @ViewBuilder
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                if showWelcomeBanner {
                    HubWelcomeBanner {
                        UserDefaultsSettingsStore.shared.hasSeenHubWelcome = true
                        withAnimation { showWelcomeBanner = false }
                    }
                }
                permissionBanner
                statusCard
                alertPill
                if FeatureFlags.isOn(.chargingPlanning) {
                    activeTripCard
                }
                departureCard
                chargeLimitSuggestionCard
                if FeatureFlags.isOn(.chargingPlanning) {
                    planningEntry
                }
                automationsEntry
                batteryEntry
                HubQuickActionsSection(
                    store: quickActionsStore,
                    vehicleId: viewModel.vehicle?.id,
                    commandStatusStore: commandStatusStore,
                    vehicleConfig: viewModel.vehicleState?.vehicleConfig,
                )
            }
            .padding(16)
        }
    }

    private var notificationBannerHideUntilBinding: Binding<Date?> {
        Binding(
            get: { notificationBannerHideUntil },
            set: { newValue in
                notificationBannerHideUntil = newValue
                UserDefaultsSettingsStore.shared.hideNotificationBannerUntil = newValue
            }
        )
    }

    private var permissionBanner: PermissionBannerView {
        PermissionBannerView(
            status: notificationScheduler.authStatus,
            hideUntil: notificationBannerHideUntilBinding,
        )
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                // No fallback string. Tesla Fleet API returns the
                // user-set vehicle name; if it's missing we'd rather
                // show empty than pretend we know — surfaces the gap
                // so it gets fixed (Tesla app side or backend side)
                // instead of silently masking with "我的 Tesla".
                Text(viewModel.displayName ?? "")
                    .font(.title3.weight(.semibold))
                Spacer()
                stateBadge
            }
            HStack(alignment: .center, spacing: 24) {
                batteryRing
                VStack(alignment: .leading, spacing: 2) {
                    if let range = viewModel.batteryRangeKm {
                        Text("\(Int(range))")
                            .font(Tokens.typographyMetricHero)
                            .foregroundStyle(.primary)
                        Text("km 续航")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(Tokens.typographyMetricHero)
                            .foregroundStyle(.secondary)
                        Text("续航未知")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            chipsSection

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
        .padding(Tokens.spacingLg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Tokens.radiusHubCard))
        .accessibilityIdentifier("hub_status_card")
    }

    typealias StatusChip = HubStatusChip

    /// Minimal flow layout — wraps children to next row when width
    /// exceeds container. Used for the status chip row so 6 chips
    /// don't overflow on narrow iPhones (SE / mini).
    private struct FlowingHStack: Layout {
        let spacing: CGFloat
        init(spacing: CGFloat = 8) { self.spacing = spacing }
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                          cache: inout ()) -> CGSize {
            let maxWidth = proposal.width ?? .infinity
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            for sub in subviews {
                let size = sub.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            return CGSize(width: maxWidth, height: y + rowHeight)
        }
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) {
            var x = bounds.minX
            var y = bounds.minY
            var rowHeight: CGFloat = 0
            for sub in subviews {
                let size = sub.sizeThatFits(.unspecified)
                if x + size.width > bounds.maxX, x > bounds.minX {
                    x = bounds.minX
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
    }

    /// Derive the visible "current vehicle state" chips from the
    /// polled `vehicleState`. Tappable chips also carry an action
    /// closure that sends the corresponding VCP command after the
    /// user confirms. Empty list → row collapses.
    private var currentStateChips: [StatusChip] {
        guard let s = viewModel.vehicleState else { return [] }
        let vid = viewModel.vehicle?.id
        var chips: [StatusChip] = []
        if s.climateKeeperMode == 3 {
            chips.append(StatusChip(
                label: "露营模式", icon: "tent.fill", color: .purple,
                confirmTitle: "关闭露营模式？",
                action: { await sendClimateKeeperOff(vid) },
            ))
        } else if s.climateKeeperMode == 2 {
            chips.append(StatusChip(
                label: "宠物模式", icon: "pawprint.fill", color: .pink,
                confirmTitle: "关闭宠物模式？",
                action: { await sendClimateKeeperOff(vid) },
            ))
        } else if s.climateKeeperMode == 1 {
            chips.append(StatusChip(
                label: "保持空调", icon: "thermometer.medium", color: .blue,
                confirmTitle: "关闭保持空调？",
                action: { await sendClimateKeeperOff(vid) },
            ))
        }
        if s.sentryModeOn == true {
            chips.append(StatusChip(
                label: "哨兵模式", icon: "shield.fill", color: .indigo,
                confirmTitle: "关闭哨兵模式？",
                action: { await sendSentryOff(vid) },
            ))
        }
        if s.cabinOverheatProtectionOn == true {
            // Tesla doesn't expose a Fleet API endpoint to disable
            // cabin-overheat-protection. Display-only.
            chips.append(StatusChip(
                label: "座舱过热保护", icon: "thermometer.sun.fill", color: .orange,
                confirmTitle: nil, action: nil,
            ))
        }
        if let cs = s.chargingState, cs == "Charging" {
            chips.append(StatusChip(
                label: "充电中", icon: "bolt.fill", color: .green,
                confirmTitle: nil, action: nil,
            ))
        }
        if s.locked == false {
            chips.append(StatusChip(
                label: "未锁车", icon: "lock.open.fill", color: .red,
                confirmTitle: "锁车？",
                action: { await sendLock(vid) },
            ))
        }
        return chips
    }

    /// Extracted from `statusCard` body so the outer view tree stays
    /// within the type-checker budget. Shows the chip row + a status
    /// banner when a recently-tapped chip's command is in flight.
    private var chipsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            let chips = currentStateChips
            if !chips.isEmpty {
                FlowingHStack(spacing: 6) {
                    ForEach(chips) { chip in
                        statusChip(chip)
                    }
                }
            }
            chipStatusBanner
        }
    }

    private func statusChip(_ chip: StatusChip) -> some View {
        Button {
            if chip.action != nil {
                pendingChipAction = chip
            }
        } label: {
            Label {
                Text(chip.label).font(.caption2.weight(.medium))
            } icon: {
                Image(systemName: chip.icon).font(.caption2)
            }
            .foregroundStyle(chip.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(chip.color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!chip.isTappable)
        .accessibilityIdentifier("hub_status_chip_\(chip.label)")
    }

    @ViewBuilder
    private var chipStatusBanner: some View {
        switch chipCommandStatus {
        case .idle: EmptyView()
        case .sending(let label):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(label).font(.caption)
            }
            .foregroundStyle(.secondary)
        case .sent(let label):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text(label).font(.caption)
            }
            .foregroundStyle(.green)
        case .failed(let message):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(message).font(.caption)
                Spacer()
                Button("关闭") { chipCommandStatus = .idle }
                    .font(.caption2)
            }
            .foregroundStyle(.orange)
        }
    }

    // MARK: - Chip → VCP command dispatchers

    private func sendClimateKeeperOff(_ vehicleId: String?) async {
        guard let vid = vehicleId else { return }
        chipCommandStatus = .sending(label: "关闭空调保持中…")
        let result = await apiService.setClimateKeeperMode(vehicleId: vid, mode: 0)
        applyChipCommandResult(result, successLabel: "已关闭空调保持")
        await viewModel.refresh()
    }

    private func sendSentryOff(_ vehicleId: String?) async {
        guard let vid = vehicleId else { return }
        chipCommandStatus = .sending(label: "关闭哨兵模式…")
        let result = await apiService.setSentryMode(vehicleId: vid, on: false)
        applyChipCommandResult(result, successLabel: "已关闭哨兵模式")
        await viewModel.refresh()
    }

    private func sendLock(_ vehicleId: String?) async {
        guard let vid = vehicleId else { return }
        chipCommandStatus = .sending(label: "锁车中…")
        let result = await apiService.lockVehicle(vehicleId: vid)
        applyChipCommandResult(result, successLabel: "已锁车")
        await viewModel.refresh()
    }

    private func applyChipCommandResult<T>(_ result: Result<T, APIError>, successLabel: String) {
        switch result {
        case .success:
            chipCommandStatus = .sent(label: successLabel)
            Task { try? await Task.sleep(nanoseconds: 2_500_000_000)
                if case .sent = chipCommandStatus { chipCommandStatus = .idle }
            }
            // 2026-05-11 bug fix: chip-dispatched commands also write a
            // CommandPending row server-side. Without this, the next
            // vehicleState change triggers refreshCommandStatuses ONCE,
            // which may catch the pending state but never the confirmed
            // state if no further telemetry change happens — the user
            // sees "正在关闭...等待车辆确认" stuck forever. Mirror the
            // AlertPill path: poll for up to 12 s so the CommandStatusBanner
            // converges to "已..." → cleared just like AlertPill commands.
            Task { await pollCommandStatusesUntilSettled() }
        case .failure(let err):
            chipCommandStatus = .failed(message: err.localizedDescription)
        }
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
                .stroke(Color.primary.opacity(Tokens.colorRingTrackAlpha), lineWidth: 10)
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
                    .font(Tokens.typographyMetricCompact)
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
        case ..<20: return Tokens.colorBatteryCritical
        case ..<50: return Tokens.colorBatteryLow
        case ..<80: return Tokens.colorBatteryNormal
        default: return Tokens.colorBatteryFull
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
        case .waking:
            // Tesla wake retry count was noisy to users — they just
            // want to know "the app is talking to the car right now",
            // not "we're on attempt 3 of 10". Hide the bookkeeping.
            Label("连接中", systemImage: "moon.zzz")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Tokens.colorStateWaking)
        case .ready:
            Label(chargingLabel, systemImage: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Tokens.colorStateReady)
        case .offline:
            Label("离线", systemImage: "circle.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Tokens.colorStateOffline)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Tokens.colorStateError)
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
            vehicleId: viewModel.vehicle?.id,
            apiService: apiService,
            commandStatusStore: commandStatusStore,
            onApplied: { Task { await viewModel.refresh() } },
            onError: { msg in alertActionError = msg },
        )
    }

    // departureCard / preheatBadge / departureSubtitle / formatDeparture
    // moved to TePlannerApp/HubDepartureCard.swift. HubView still owns
    // preheatStatus + triggerPreheat() since the notification handler
    // calls in directly.
    private var departureCard: some View {
        HubDepartureCard(
            scheduledDeparture: scheduledDeparture,
            preheatStatus: preheatStatus,
            onTap: { showingDepartureSheet = true },
        )
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
    // welcomeBanner moved to TePlannerApp/HubWelcomeBanner.swift.

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
        if commandStatusStore.activePending != nil || commandStatusStore.activeQueued != nil {
            CommandStatusBanner(
                pending: commandStatusStore.activePending,
                queued: commandStatusStore.activeQueued,
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
        .padding(.horizontal, Tokens.spacingMdPlus)
        .padding(.vertical, Tokens.spacingSmPlus)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("telemetry_waiting_pill")
    }

    private var planningEntry: some View {
        NavigationLink {
            MapHomeView(apiService: apiService, viewModel: viewModel,
                        commandStatusStore: commandStatusStore,
                        activeTripStore: activeTripStore)
        } label: {
            HubEntryCard(
                icon: "bolt.fill",
                title: "充电规划",
                accessibilityId: "hub_entry_planning"
            )
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    /// "进行中行程" card — visible only while an ActiveTrip is in
    /// flight. Shows the next stop name + remaining count, and lets
    /// the user manually advance to the next stop (auto-advance
    /// lives in the cron monitor in phase 2).
    @ViewBuilder
    private var activeTripCard: some View {
        if let trip = activeTripStore.trip,
           let nextOrCurrent = trip.currentStop ?? trip.stops.first {
            HubActiveTripCard(
                trip: trip,
                nextStop: nextOrCurrent,
                isLoading: activeTripStore.isLoading,
                onAdvance: { Task { await activeTripStore.advance() } },
                onCancel: { Task { await activeTripStore.cancel() } },
            )
        }
    }

    private var automationsEntry: some View {
        NavigationLink {
            AutomationsHomeView(rulesStore: rulesStore, apiService: apiService, snoozeStore: snoozeStore, automationEngine: automationEngine)
        } label: {
            HubEntryCard(
                icon: "bell.badge.fill",
                title: "自动化",
                accessibilityId: "hub_entry_automations"
            )
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    private var batteryEntry: some View {
        NavigationLink {
            BatteryView(
                sessionStore: chargingSessionStore,
                apiService: apiService,
                vehicleId: viewModel.vehicle?.id,
                currentChargeLimitSoc: viewModel.vehicleState?.chargeLimitSoc,
                commandStatusStore: commandStatusStore,
                onLimitApplied: { Task { await viewModel.refresh() } }
            )
        } label: {
            HubEntryCard(
                icon: "battery.100.bolt",
                title: "电池管理",
                accessibilityId: "hub_entry_battery"
            )
        }
        .buttonStyle(PressableCardButtonStyle())
    }

    // batterySubtitle / automationsSubtitle / firingRuleName removed
    // 2026-05-11 — hub entry cards now title-only, status visible
    // on the inner pages (BatteryView / AutomationsHomeView) where
    // it belongs.
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
    /// Optional. Removed from all hub entries 2026-05-11 — user
    /// feedback was the subtitles were noise (例举规则名 / 计数 /
    /// 兜底文案), the interesting state lives one tap deeper. Kept
    /// optional so existing call sites in tests / other surfaces
    /// can pass a subtitle if they truly need one later.
    var subtitle: String? = nil
    let accessibilityId: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Tokens.spacingMdPlus)
        .padding(.horizontal, Tokens.spacingLg)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Tokens.radiusHubCard))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.radiusHubCard)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .accessibilityIdentifier(accessibilityId)
    }
}
