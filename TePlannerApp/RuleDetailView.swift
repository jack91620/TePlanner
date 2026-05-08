import SwiftUI
import TePlannerKit

/// 自动化规则的只读详情页。Phase 10.4 重写：不再 dump schema 字段
/// （preset_id / dotted entity / trigger type / capability id 等），
/// 而是用一句话 + 卡片把「触发条件 → 满足后做什么」讲清楚。模板里的
/// {duration_human} 占位符在预览时用规则自己的阈值填上。
struct RuleDetailView: View {
    let ruleId: String
    @ObservedObject var rulesStore: AutomationRulesStore
    @ObservedObject var capabilitiesStore: CapabilitiesStore

    @State private var showingEditor = false
    @State private var showingDeleteConfirm = false
    @State private var workingError: String?
    @State private var pendingDuplicate: RuleRecord?
    @Environment(\.dismiss) private var dismiss

    private var record: RuleRecord? {
        rulesStore.rules.first { $0.id == ruleId }
    }

    var body: some View {
        Group {
            if let r = record {
                Form {
                    headerSection(r)
                    triggerSection(r.spec)
                    actionSections(r.spec)
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
                                .background(Color.blue.opacity(0.15), in: Capsule())
                                .foregroundStyle(.blue)
                        } else {
                            Text("自定义")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15), in: Capsule())
                                .foregroundStyle(.green)
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
                    LocalNotificationScheduler.shared.fireSample(
                        title: title, body: body, identifier: r.id,
                    )
                } label: {
                    Label("试发通知预览", systemImage: "bell.badge")
                }
                .accessibilityIdentifier("rule_test_fire_button")
            } footer: {
                Text("发送一条样例通知到系统，预览推送视觉。不会真触发车辆动作。")
                    .font(.caption2)
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

    @ViewBuilder
    private func triggerSection(_ spec: RuleSpec) -> some View {
        Section("当") {
            Text(RuleDisplay.triggerSentence(spec))
                .font(.body)
                .padding(.vertical, 4)
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
        guard let ts = UserDefaultsSettingsStore.shared.ruleSnooze[ruleId] else { return nil }
        return Date(timeIntervalSince1970: ts)
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
        let store = UserDefaultsSettingsStore.shared
        if snoozedUntil(for: r.id) != nil {
            Button("取消静音", systemImage: "bell.slash.fill") {
                var s = store.ruleSnooze
                s.removeValue(forKey: r.id)
                store.ruleSnooze = s
                rulesStore.objectWillChange.send()
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
        let store = UserDefaultsSettingsStore.shared
        var s = store.ruleSnooze
        s[r.id] = Date().addingTimeInterval(hours * 3600).timeIntervalSince1970
        store.ruleSnooze = s
        rulesStore.objectWillChange.send()
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
        let store = UserDefaultsSettingsStore.shared
        var s = store.ruleSnooze
        s[r.id] = target.timeIntervalSince1970
        store.ruleSnooze = s
        rulesStore.objectWillChange.send()
    }
}
