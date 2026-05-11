import SwiftUI
import TePlannerKit
import UserNotifications

/// 自动化规则的只读详情页。Phase 10.4 重写：不再 dump schema 字段
/// （preset_id / dotted entity / trigger type / capability id 等），
/// 而是用一句话 + 卡片把「触发条件 → 满足后做什么」讲清楚。模板里的
/// {duration_human} 占位符在预览时用规则自己的阈值填上。
struct RuleDetailView: View {
    let ruleId: String
    @ObservedObject var rulesStore: AutomationRulesStore
    @ObservedObject var capabilitiesStore: CapabilitiesStore
    @ObservedObject var snoozeStore: BackendSnoozeStore

    @State private var showingEditor = false
    @State private var showingDeleteConfirm = false
    @State private var workingError: String?
    @State private var pendingDuplicate: RuleRecord?
    @State private var pendingThresholdMinutes: Int?
    @State private var savingThreshold = false
    @State private var testFireFeedback: TestFireFeedback?
    @Environment(\.dismiss) private var dismiss

    enum TestFireFeedback { case sent, denied(String) }

    private var record: RuleRecord? {
        rulesStore.rules.first { $0.id == ruleId }
    }

    var body: some View {
        Group {
            if let r = record {
                Form {
                    headerSection(r)
                    triggerSection(r.spec)
                    thresholdSection(r)
                    geofencePromptSection(r)
                    actionSections(r.spec)
                    presetExplanationSection(r)
                    testFireSection(r)
                    if let err = workingError {
                        Section {
                            Text(err).foregroundStyle(.red).font(.caption)
                        }
                    }
                }
                .navigationTitle(r.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent(r) }
                .sheet(isPresented: $showingEditor) {
                    NavigationStack {
                        RuleBuilderView(
                            initial: r,
                            rulesStore: rulesStore,
                            capabilitiesStore: capabilitiesStore
                        )
                    }
                }
                .confirmationDialog("确定删除「\(r.name)」？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        Task {
                            let ok = await rulesStore.delete(id: r.id)
                            if ok {
                                dismiss()
                            } else {
                                workingError = rulesStore.lastError
                            }
                        }
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("删除后无法恢复。")
                }
                .sheet(item: $pendingDuplicate) { source in
                    // "复制为新规则" — open the builder pre-filled with
                    // a clone of this rule. Saving creates a separate
                    // user-authored rule; the source stays untouched.
                    NavigationStack {
                        RuleBuilderView(
                            initial: nil,
                            template: cloneForDuplicate(source),
                            rulesStore: rulesStore,
                            capabilitiesStore: capabilitiesStore
                        )
                    }
                }
            } else {
                ProgressView()
            }
        }
    }

    /// Build a clone of `source` for "复制为新规则": null id (forces
    /// create on save), null preset_id (clone is user-authored), and
    /// a "副本" suffix on the name. Same trigger + actions otherwise.
    private func cloneForDuplicate(_ source: RuleRecord) -> RuleRecord {
        var nextName = "\(source.name) 副本"
        let existing = Set(rulesStore.rules.map(\.name))
        var i = 2
        while existing.contains(nextName) {
            nextName = "\(source.name) 副本 \(i)"
            i += 1
        }
        return RuleRecord(
            id: "",                  // empty → builder treats as new
            presetId: nil,           // user-authored copy
            name: nextName,
            enabled: source.enabled,
            spec: source.spec,
            version: 1
        )
    }

    @ToolbarContentBuilder
    private func toolbarContent(_ r: RuleRecord) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("编辑", systemImage: "pencil") { showingEditor = true }
                Button("复制为新规则", systemImage: "plus.square.on.square") {
                    pendingDuplicate = r
                }
                snoozeMenu(for: r)
                Divider()
                Button("复制 JSON 规格", systemImage: "doc.on.doc") {
                    copySpecJSON(r)
                }
                if r.presetId == nil {
                    Button("删除", systemImage: "trash", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection(_ r: RuleRecord) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.name).font(.headline)
                    HStack(spacing: 6) {
                        if r.presetId != nil {
                            Text("预设")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Tokens.colorBadgePresetBg.opacity(Tokens.colorBadgePresetBgAlpha), in: Capsule())
                                .foregroundStyle(Tokens.colorBadgePresetFg)
                        } else {
                            Text("自定义")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Tokens.colorBadgeCustomBg.opacity(Tokens.colorBadgeCustomBgAlpha), in: Capsule())
                                .foregroundStyle(Tokens.colorBadgeCustomFg)
                        }
                        Text(r.enabled ? "已启用" : "已停用")
                            .font(.caption)
                            .foregroundStyle(r.enabled ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                    }
                    if let until = snoozedUntil(for: r.id) {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.caption2)
                            Text("已静音至 \(Self.snoozeFull(until))")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                    }
                    if let lastFired = r.lastFiredAt {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.badge.fill")
                                .font(.caption2)
                                .foregroundStyle(.tint)
                            Text("上次触发：\(Self.relative(lastFired))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if r.enabled {
                        Text("尚未触发过")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if r.enabled, let next = nextCronFireDate(in: r.spec) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            Text("下次触发：\(Self.absolute(next))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    /// 试发一条 sample 通知到系统 — 让用户在保存前预览推送视觉。
    /// Pulls title + body from the rule's first notify action; falls
    /// through gracefully on rules without a notify-shaped action
    /// (cron+invoke, future wait_for_state).
    @ViewBuilder
    private func testFireSection(_ r: RuleRecord) -> some View {
        if let (title, body) = sampleNotificationText(for: r) {
            Section {
                Button {
                    fireTestNotification(title: title, body: body, ruleId: r.id)
                } label: {
                    Label("试发通知预览", systemImage: "bell.badge")
                }
                .accessibilityIdentifier("rule_test_fire_button")
                if let feedback = testFireFeedback {
                    switch feedback {
                    case .sent:
                        Label {
                            Text("已发送 — 1 秒后会出现在通知中心。如果系统未显示横幅，请到「设置 → 通知 → Tautomation」开启横幅样式。")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .foregroundStyle(.green)
                    case .denied(let message):
                        Label {
                            Text(message).font(.caption)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(.orange)
                    }
                }
            } footer: {
                Text("发送一条样例通知到系统，预览推送视觉。不会真触发车辆动作。")
                    .font(.caption2)
            }
        }
    }

    private func fireTestNotification(title: String, body: String, ruleId: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                guard settings.authorizationStatus == .authorized
                        || settings.authorizationStatus == .provisional else {
                    testFireFeedback = .denied("尚未获得通知权限。请到「设置 → 通知 → Tautomation」开启。")
                    Task {
                        try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                        await MainActor.run {
                            if case .denied = testFireFeedback { testFireFeedback = nil }
                        }
                    }
                    return
                }
                LocalNotificationScheduler.shared.fireSample(
                    title: title, body: body, identifier: ruleId,
                )
                withAnimation { testFireFeedback = .sent }
                Task {
                    try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                    await MainActor.run {
                        if case .sent = testFireFeedback {
                            withAnimation { testFireFeedback = nil }
                        }
                    }
                }
            }
        }
    }

    private func sampleNotificationText(for r: RuleRecord) -> (String, String)? {
        let bucketKeys = ["actions_above", "actions", "actions_below"]
        for key in bucketKeys {
            guard let arr = r.spec[key]?.arrayValue,
                  let first = arr.first?.objectValue else { continue }
            let aType = first.string("type") ?? ""
            guard aType == "notify" || aType == "notify_and_offer" else { continue }
            let titleTpl = first.string("title") ?? ""
            let bodyTpl = first.string("body") ?? ""
            // Substitute placeholders with sample values, same way
            // RuleDisplay.previewTemplate does for the builder preview.
            let title = RuleDisplay.previewTemplate(titleTpl, spec: r.spec)
            let body = RuleDisplay.previewTemplate(bodyTpl, spec: r.spec)
            if !title.isEmpty || !body.isEmpty {
                return (title, body)
            }
        }
        return nil
    }

    /// "刚刚 / X 分钟前 / 昨天 / 5 月 8 日" — relative-time vocabulary
    /// matching how iOS 邮件 / 信息 surface timestamps.
    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// "今天 HH:mm / 明天 HH:mm / 周X HH:mm / M月d日 HH:mm" —
    /// absolute time used for next-cron-fire labels. When the target
    /// is less than 24 h away the relative-time suffix is appended
    /// (e.g. '今天 07:30（约 30 分钟后）').
    private static func absolute(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(date) {
            f.dateFormat = "今天 HH:mm"
        } else if cal.isDateInTomorrow(date) {
            f.dateFormat = "明天 HH:mm"
        } else {
            let dayDelta = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
            if dayDelta < 7 {
                f.dateFormat = "EEEE HH:mm"
            } else {
                f.dateFormat = "M月d日 HH:mm"
            }
        }
        let base = f.string(from: date)
        let secondsAway = date.timeIntervalSinceNow
        guard secondsAway > 0, secondsAway < 24 * 3600 else { return base }
        let relative: String
        if secondsAway < 60 {
            relative = "1 分钟内"
        } else if secondsAway < 3600 {
            relative = "约 \(Int(secondsAway / 60)) 分钟后"
        } else {
            let hours = Int(secondsAway / 3600)
            let mins = Int(secondsAway.truncatingRemainder(dividingBy: 3600) / 60)
            if mins < 5 {
                relative = "约 \(hours) 小时后"
            } else {
                relative = "\(hours) 小时 \(mins) 分钟后"
            }
        }
        return "\(base)（\(relative)）"
    }

    private func nextCronFireDate(in spec: RuleSpec) -> Date? {
        RuleDisplay.nextCronFire(spec: spec)
    }

    @ViewBuilder
    private func triggerSection(_ spec: RuleSpec) -> some View {
        Section("当") {
            Text(RuleDisplay.triggerSentence(spec))
                .font(.body)
                .padding(.vertical, 4)
        }
    }

    /// Inline 阈值调节. Avoids the extra round-trip through Edit →
    /// builder → save. Only shown for state_duration rules where
    /// for_minutes makes sense; cron / state_transition rules
    /// suppress the section.
    @ViewBuilder
    private func thresholdSection(_ r: RuleRecord) -> some View {
        if let trigger = r.spec["trigger"]?.objectValue,
           trigger.string("type") == "state_duration",
           let stored = trigger["for_minutes"]?.intValue {
            let bind = Binding<Int>(
                get: { pendingThresholdMinutes ?? stored },
                set: { pendingThresholdMinutes = $0 },
            )
            Section {
                let minutes = bind.wrappedValue
                HStack {
                    Text("持续时长")
                    Spacer()
                    Text(RuleDisplay.formatDurationMinutes(minutes))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(bind.wrappedValue) },
                        set: { bind.wrappedValue = Int($0) },
                    ),
                    in: 5...1440,
                    step: 5,
                )
                if pendingThresholdMinutes != nil, pendingThresholdMinutes != stored {
                    HStack {
                        Button("撤销") {
                            pendingThresholdMinutes = nil
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button {
                            saveThreshold(r, minutes: bind.wrappedValue)
                        } label: {
                            if savingThreshold {
                                ProgressView()
                            } else {
                                Text("保存阈值")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(savingThreshold)
                    }
                }
            } header: {
                Text("阈值")
            } footer: {
                Text("修改触发该规则需要的状态持续时长。也可以从「编辑」进入完整构建器调整其他字段。")
                    .font(.caption2)
            }
        }
    }

    /// For unconfigured geofence rules, surface a prominent
    /// 选择地点 CTA on the detail page so users don't have to dig
    /// through the … menu → 编辑 → builder to set the center. Tapping
    /// opens the same builder sheet, scrolled to the location row.
    @ViewBuilder
    private func geofencePromptSection(_ r: RuleRecord) -> some View {
        if isUnconfiguredGeofence(r.spec) {
            Section {
                Button {
                    showingEditor = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("选择中心地点")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("规则需要中心位置才会生效")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .listRowBackground(Tokens.colorWashSnooze.opacity(Tokens.colorWashSnoozeAlpha))
        }
    }

    private func isUnconfiguredGeofence(_ spec: RuleSpec) -> Bool {
        guard let trigger = spec["trigger"]?.objectValue,
              trigger.string("type") == "geofence" else { return false }
        let lat = trigger.double("lat") ?? 0
        let lng = trigger.double("lng") ?? 0
        return abs(lat) < 0.0001 && abs(lng) < 0.0001
    }

    /// Inline 'why this rule matters' callout for presets — explains
    /// the underlying Tesla behavior so users without deep familiarity
    /// (e.g. 露营模式 = HVAC stays on while parked) understand why
    /// the reminder exists. User-authored rules suppress the section.
    @ViewBuilder
    private func presetExplanationSection(_ r: RuleRecord) -> some View {
        if let presetId = r.presetId, let text = Self.presetExplanation(presetId) {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            } header: {
                Text("为什么需要这条规则？")
            }
        }
    }

    private static func presetExplanation(_ presetId: String) -> String? {
        switch presetId {
        case "camp_mode_overstay":
            return "露营模式（Camp Mode）开启时空调会持续运行，电池每小时消耗约 2–4%。长时间停车未撤销容易回来发现电量大降，这条规则在你设定的时长后提醒你确认状态。"
        case "sentry_mode_overstay":
            return "哨兵模式（Sentry Mode）持续摄录车辆四周，每天约消耗 8–10% 电量。长期开启会显著加速行车电脑老化，建议在固定停车场（家、公司）关闭。"
        case "cabin_overheat_protection":
            return "夏季阳光下停车，车舱温度可在 20 分钟内升到 60℃ 以上，对宠物、儿童、车内电子设备都不安全。Tesla 的座舱过热保护会自动开启风扇/空调，本规则在它启动时通知你。"
        case "charge_complete":
            return "充电完成后再插枪会占用充电桩位置，影响其他车主。这条规则在你的车充满后立即提醒，方便你及时拔枪。"
        case "left_unlocked_warning":
            return "Tesla 在你下车后会按设置自动锁车，但偶尔会因为钥匙信号、网络等原因失败。这条规则在停车 N 分钟仍未锁车时提醒你确认。"
        case "closure_left_open_warning":
            return "车窗 / 后备箱忘关会让降雨、灰尘、虫子进入车内。这条规则在长时间未关闭时提醒。"
        case "weekday_preheat":
            return "出发前 10–20 分钟启动 HVAC 可让车舱达到舒适温度，冬天还能为电池预热提升续航。本规则按工作日的固定时间提醒你启动预热。"
        case "geofence_arrive_home":
            return "车辆进入你设定的「家」范围时通知你。可以作为车机轨迹的私人提示，也能配合家庭智能设备（车回家就开门 / 灯）。先用「编辑」打开地图选好家的位置再启用。"
        case "geofence_leave_home_sentry":
            return "出小区自动开哨兵，回家自动关——可以代替手动每次切换。先用「编辑」打开地图选「家」的位置再启用。"
        case "geofence_arrive_work_lock":
            return "下车前忘锁车的常见场景：到公司停好就走人。本规则在车辆进入公司范围时提示一键锁车。先用「编辑」打开地图选「公司」位置再启用。"
        default:
            return nil
        }
    }

    /// Encode the rule (id, name, enabled, spec, version) as JSON
    /// and put it on the pasteboard. Useful when the user wants to
    /// share a custom rule with someone, or paste into an issue
    /// report. Pretty-printed for human readability.
    private func copySpecJSON(_ r: RuleRecord) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(r), let json = String(data: data, encoding: .utf8) {
            UIPasteboard.general.string = json
        }
    }

    private func saveThreshold(_ r: RuleRecord, minutes: Int) {
        savingThreshold = true
        Task {
            var spec = r.spec
            if case .object(var trigger) = spec["trigger"] ?? .null {
                trigger["for_minutes"] = .int(minutes)
                spec["trigger"] = .object(trigger)
            }
            let ok = await rulesStore.update(id: r.id, spec: spec)
            await MainActor.run {
                savingThreshold = false
                if ok {
                    pendingThresholdMinutes = nil
                } else {
                    workingError = rulesStore.lastError
                }
            }
        }
    }

    @ViewBuilder
    private func actionSections(_ spec: RuleSpec) -> some View {
        // state_duration: 优先展示 actions_above（达到阈值时执行），
        // actions_below 作为补充信息靠后展示。
        if case .array(let above) = spec["actions_above"] ?? .null, !above.isEmpty {
            Section("那么") {
                ForEach(0..<above.count, id: \.self) { i in
                    if let dict = above[i].objectValue {
                        actionCard(dict, spec: spec)
                    }
                }
            }
        }
        if case .array(let below) = spec["actions_below"] ?? .null, !below.isEmpty {
            Section {
                ForEach(0..<below.count, id: \.self) { i in
                    if let dict = below[i].objectValue {
                        actionCard(dict, spec: spec, dimmed: true)
                    }
                }
            } header: {
                Text("尚未达到阈值时")
            } footer: {
                Text("条件已成立但未到阈值。仅作为状态指示，不会推送通知。")
                    .font(.caption2)
            }
        }
        // state_transition 用 `actions`
        if case .array(let actions) = spec["actions"] ?? .null, !actions.isEmpty {
            Section("那么") {
                ForEach(0..<actions.count, id: \.self) { i in
                    if let dict = actions[i].objectValue {
                        actionCard(dict, spec: spec)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionCard(
        _ action: [String: JSONValue],
        spec: RuleSpec,
        dimmed: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: severityIcon(action))
                    .foregroundStyle(severityColor(action))
                Text(severityLabel(action))
                    .font(.caption.bold())
                    .foregroundStyle(severityColor(action))
                Spacer()
            }
            Text(action.string("title") ?? "")
                .font(.subheadline.bold())
            Text(RuleDisplay.previewTemplate(action.string("body") ?? "", spec: spec))
                .font(.callout)
                .foregroundStyle(.secondary)
            if let cap = action.string("capability") {
                let label = action.string("primary_action_label") ?? RuleDisplay.capabilityName(cap)
                if cap != "automation.dismiss" {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                        Text("操作按钮：\(label)（\(RuleDisplay.capabilityName(cap))）")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                    .padding(.top, 2)
                } else if action.string("primary_action_label") != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                        Text("操作按钮：\(label)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(dimmed ? 0.7 : 1.0)
    }

    private func severityIcon(_ action: [String: JSONValue]) -> String {
        switch action.string("severity") {
        case "critical": return "exclamationmark.triangle.fill"
        case "info":     return "info.circle.fill"
        default:          return "bell.fill"
        }
    }

    private func severityColor(_ action: [String: JSONValue]) -> Color {
        switch action.string("severity") {
        case "critical": return .orange
        case "info":     return .blue
        default:          return .secondary
        }
    }

    private func severityLabel(_ action: [String: JSONValue]) -> String {
        switch action.string("severity") {
        case "critical": return "重要提醒"
        case "info":     return "信息提醒"
        default:          return "通知"
        }
    }

    // MARK: - Snooze

    private func snoozedUntil(for ruleId: String) -> Date? {
        snoozeStore.activeUntil[ruleId]
    }

    private static func snoozeFull(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(date) {
            f.dateFormat = "今天 HH:mm"
        } else if cal.isDateInTomorrow(date) {
            f.dateFormat = "明天 HH:mm"
        } else {
            f.dateFormat = "M月d日 HH:mm"
        }
        return f.string(from: date)
    }

    @ViewBuilder
    private func snoozeMenu(for r: RuleRecord) -> some View {
        if snoozedUntil(for: r.id) != nil {
            Button("取消静音", systemImage: "bell.slash.fill") {
                Task { await snoozeStore.unsnooze(ruleId: r.id) }
            }
        } else {
            Menu("静音", systemImage: "bell.slash") {
                Button("静音 1 小时") { snooze(r, hours: 1) }
                Button("静音 4 小时") { snooze(r, hours: 4) }
                Button("静音至明早 8 点") { snoozeUntilMorning(r) }
            }
        }
    }

    private func snooze(_ r: RuleRecord, hours: Double) {
        Task { await snoozeStore.snooze(ruleId: r.id, hours: hours, reason: nil) }
    }

    private func snoozeUntilMorning(_ r: RuleRecord) {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 0
        var target = cal.date(from: components) ?? Date().addingTimeInterval(8 * 3600)
        if target <= Date() {
            target = cal.date(byAdding: .day, value: 1, to: target) ?? target
        }
        Task { await snoozeStore.snooze(ruleId: r.id, until: target, reason: nil) }
    }
}
