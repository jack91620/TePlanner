import SwiftUI
import TePlannerKit

/// Phase 10.3.C — replacement for AutomationsListView. Lists every
/// rule on the user's account with a visible enabled toggle, swipe
/// delete (only for user-authored rules; presets stay locked), and a
/// "+" toolbar entry that pushes the visual builder.
///
/// Tap a row → push RuleDetailView (read-only summary + Edit /
/// Disable / Delete). Edit pushes RuleBuilderView pre-filled with
/// the spec.
struct AutomationsHomeView: View {
    @ObservedObject var rulesStore: AutomationRulesStore
    @StateObject private var capabilitiesStore: CapabilitiesStore
    @ObservedObject private var snoozeStore: BackendSnoozeStore
    @State private var showingBuilder = false
    @State private var workingError: String?
    @State private var pendingDelete: RuleRecord?
    @State private var pendingDuplicate: RuleRecord?
    @State private var searchText: String = ""
    @State private var snoozeDialogRule: RuleRecord?

    private let apiService: APIServiceProtocol

    init(rulesStore: AutomationRulesStore, apiService: APIServiceProtocol, snoozeStore: BackendSnoozeStore) {
        self.rulesStore = rulesStore
        self.apiService = apiService
        self.snoozeStore = snoozeStore
        _capabilitiesStore = StateObject(wrappedValue: CapabilitiesStore(apiService: apiService))
    }

    var body: some View {
        List {
            if rulesStore.rules.isEmpty && rulesStore.isLoading {
                Section { ProgressView("加载规则…") }
            }
            if rulesStore.rules.isEmpty && !rulesStore.isLoading,
               let err = rulesStore.lastError {
                loadErrorSection(message: err)
            } else if rulesStore.rules.isEmpty && !rulesStore.isLoading {
                emptyStateSection
            }
            if snoozedCount > 0 {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(snoozedCount) 条规则当前静音中")
                                .font(.subheadline.weight(.medium))
                            Text("静音期间不会推送通知；点击规则可查看到期时间。")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("全部恢复") {
                            unsnoozeAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .listRowBackground(Color.orange.opacity(0.08))
            }
            if !presetRules.isEmpty {
                Section {
                    ForEach(presetRules) { record in
                        ruleRow(record)
                            .swipeActions(edge: .leading) { snoozeSwipeButton(for: record) }
                    }
                } header: {
                    Text("预设 · \(presetRules.count)")
                } footer: {
                    Text("左滑静音、长按弹出更多操作（含上移 / 下移 / 复制）；右上角钟形图标可查看历史触发。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if !customRules.isEmpty {
                Section("我的自动化 · \(customRules.count)") {
                    ForEach(customRules) { record in
                        ruleRow(record)
                            .swipeActions(edge: .leading) { snoozeSwipeButton(for: record) }
                            .swipeActions {
                                Button(role: .destructive) {
                                    pendingDelete = record
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            if let err = workingError {
                Section {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .navigationTitle("自动化")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索规则")
        .refreshable {
            await rulesStore.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    NavigationLink {
                        RecentFiresView(apiService: apiService)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("automations_activity_button")
                    Button {
                        showingBuilder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("automations_add_button")
                }
            }
        }
        .task {
            await capabilitiesStore.refreshIfNeeded()
        }
        .sheet(isPresented: $showingBuilder) {
            NavigationStack {
                RuleBuilderView(
                    initial: nil,
                    rulesStore: rulesStore,
                    capabilitiesStore: capabilitiesStore
                )
            }
        }
        .sheet(item: $pendingDuplicate) { source in
            NavigationStack {
                RuleBuilderView(
                    initial: nil,
                    template: cloneForDuplicate(source),
                    rulesStore: rulesStore,
                    capabilitiesStore: capabilitiesStore
                )
            }
        }
        .confirmationDialog(
            "确定删除「\(pendingDelete?.name ?? "")」？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let target = pendingDelete {
                    Task {
                        let ok = await rulesStore.delete(id: target.id)
                        if !ok { workingError = rulesStore.lastError }
                    }
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("删除后无法恢复。如只想暂停，可在右侧关闭开关。")
        }
        .confirmationDialog(
            snoozeDialogRule.map { "「\($0.name)」" } ?? "",
            isPresented: Binding(
                get: { snoozeDialogRule != nil },
                set: { if !$0 { snoozeDialogRule = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let r = snoozeDialogRule {
                if snoozeUntil(for: r.id) != nil {
                    Button("取消静音") {
                        unsnooze(r)
                        snoozeDialogRule = nil
                    }
                } else {
                    Button("静音 1 小时")    { snooze(r, hours: 1); snoozeDialogRule = nil }
                    Button("静音 4 小时")    { snooze(r, hours: 4); snoozeDialogRule = nil }
                    Button("静音至明早 8 点") { snoozeUntilMorning(r); snoozeDialogRule = nil }
                }
                Button("取消", role: .cancel) { snoozeDialogRule = nil }
            }
        }
    }

    @ViewBuilder
    private func snoozeSwipeButton(for record: RuleRecord) -> some View {
        if snoozeUntil(for: record.id) != nil {
            Button {
                unsnooze(record)
            } label: {
                Label("取消静音", systemImage: "bell.slash.fill")
            }
            .tint(.orange)
        } else {
            Button {
                snoozeDialogRule = record
            } label: {
                Label("静音", systemImage: "bell.slash")
            }
            .tint(.orange)
        }
    }

    /// True iff this is a geofence rule whose lat/lng are still the
    /// preset placeholder (0, 0) — fires nothing in practice but
    /// surfacing the unconfigured state on the row prevents 'why
    /// isn't it working?'.
    private func isUnconfiguredGeofence(_ record: RuleRecord) -> Bool {
        guard let trigger = record.spec["trigger"]?.objectValue,
              trigger.string("type") == "geofence" else { return false }
        let lat = trigger.double("lat") ?? 0
        let lng = trigger.double("lng") ?? 0
        return abs(lat) < 0.0001 && abs(lng) < 0.0001
    }

    private func unsnooze(_ record: RuleRecord) {
        Task { await snoozeStore.unsnooze(ruleId: record.id) }
    }

    private func unsnoozeAll() {
        let active = snoozeStore.activeUntil
        Task {
            for ruleId in active.keys {
                await snoozeStore.unsnooze(ruleId: ruleId)
            }
        }
    }

    private var snoozedCount: Int {
        snoozeStore.activeUntil.count
    }

    @ViewBuilder
    private func ruleRow(_ record: RuleRecord) -> some View {
        NavigationLink {
            RuleDetailView(
                ruleId: record.id,
                rulesStore: rulesStore,
                capabilitiesStore: capabilitiesStore,
                snoozeStore: snoozeStore
            )
        } label: {
            ruleRowLabel(record)
        }
        .contextMenu {
            Button {
                Task {
                    let ok = await rulesStore.update(
                        id: record.id, enabled: !record.enabled,
                    )
                    if !ok { workingError = rulesStore.lastError }
                }
            } label: {
                if record.enabled {
                    Label("停用", systemImage: "pause.circle")
                } else {
                    Label("启用", systemImage: "play.circle")
                }
            }
            Divider()
            Button {
                moveRule(record, by: -1)
            } label: {
                Label("上移", systemImage: "arrow.up")
            }
            .disabled(!canMove(record, by: -1))
            Button {
                moveRule(record, by: 1)
            } label: {
                Label("下移", systemImage: "arrow.down")
            }
            .disabled(!canMove(record, by: 1))
            Divider()
            Button {
                pendingDuplicate = record
            } label: {
                Label("复制为新规则", systemImage: "plus.square.on.square")
            }
            snoozeMenu(for: record)
            if record.presetId == nil {
                Divider()
                Button(role: .destructive) {
                    pendingDelete = record
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    /// True iff the rule has a sibling in the same section it could
    /// swap with — preset rule with another preset / custom with
    /// another custom. Cross-section moves aren't allowed because
    /// the section split (preset vs custom) is structural.
    private func canMove(_ record: RuleRecord, by delta: Int) -> Bool {
        let bucket = record.presetId == nil ? customRules : presetRules
        guard let idx = bucket.firstIndex(where: { $0.id == record.id }) else {
            return false
        }
        let target = idx + delta
        return target >= 0 && target < bucket.count
    }

    /// Move a rule one position in its section. delta = -1 = up,
    /// +1 = down. Phase D.2 persists via PUT /automations/order on the
    /// backend (display_order column); the response is the freshly
    /// sorted full list which AutomationRulesStore swaps into its
    /// cache so the UI re-renders.
    ///
    /// We send the full ordered list (preset + custom rows merged in
    /// the order they currently appear) so positions stay stable
    /// across mixed buckets.
    private func moveRule(_ record: RuleRecord, by delta: Int) {
        let bucket = record.presetId == nil ? customRules : presetRules
        guard let idx = bucket.firstIndex(where: { $0.id == record.id }) else {
            return
        }
        let target = idx + delta
        guard target >= 0, target < bucket.count else { return }
        var reorderedBucket = bucket
        let moved = reorderedBucket.remove(at: idx)
        reorderedBucket.insert(moved, at: target)
        let bucketIds = Set(bucket.map(\.id))
        // Preserve the relative order of the OTHER section so we send
        // a coherent full-list to the server.
        let other = rulesStore.rules.filter { !bucketIds.contains($0.id) }
        let merged = (record.presetId == nil
            ? presetRules + reorderedBucket
            : reorderedBucket + customRules)
        // Defensive: if the merge somehow drops rows that exist on
        // the server, fall back to appending them so order PUT is
        // still well-formed.
        let mergedIds = Set(merged.map(\.id))
        let stragglers = other.filter { !mergedIds.contains($0.id) }
        let payload = (merged + stragglers).map(\.id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { await rulesStore.reorder(ruleIds: payload) }
    }

    @ViewBuilder
    private func ruleRowLabel(_ record: RuleRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // iOS 快捷指令-style accent: trigger-typed icon in a
            // colored rounded square, dimmed when rule is off.
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(triggerAccent(for: record).opacity(record.enabled ? 0.18 : 0.08))
                Image(systemName: RuleDisplay.triggerSymbol(record.spec))
                    .foregroundStyle(record.enabled ? AnyShapeStyle(triggerAccent(for: record)) : AnyShapeStyle(.secondary))
                    .font(.subheadline)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                // "When X happens, do Y" — the iOS Shortcuts pattern.
                // Dimmed prefix labels (当 / 那么) help users parse
                // long sentences at a glance.
                HStack(alignment: .top, spacing: 4) {
                    Text("当")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(triggerSummary(record.spec))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                let action = RuleDisplay.actionSentence(record.spec)
                if !action.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Text("那么")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(action)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                if isUnconfiguredGeofence(record) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("请先设置地点")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
                }
                if let until = snoozeUntil(for: record.id) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.caption2)
                        Text("已静音至 \(Self.snoozeLabel(until))")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
                } else if let last = record.lastFiredAt {
                    Text("上次触发：\(Self.relative(last))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 6)
            Toggle(
                "",
                isOn: Binding(
                    get: { record.enabled },
                    set: { newValue in
                        // Light haptic — matches iOS Mail / 提醒事项
                        // toggle feel and confirms the tap landed on
                        // the small switch without waiting for the
                        // round-trip to the backend.
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task {
                            let ok = await rulesStore.update(id: record.id, enabled: newValue)
                            if !ok { workingError = rulesStore.lastError }
                        }
                    }
                )
            )
            .labelsHidden()
        }
        .accessibilityIdentifier("automation_row_\(record.id)")
    }

    private var presetRules: [RuleRecord] {
        // Phase D.2 — server already sorted by display_order then
        // canonical preset/created-at order; we just preserve the
        // received order and split into buckets.
        applySearch(rulesStore.rules.filter { $0.presetId != nil })
    }

    private var customRules: [RuleRecord] {
        applySearch(rulesStore.rules.filter { $0.presetId == nil })
    }

    /// Filter by search text. Matches both the rule name and the
    /// trigger / action sentences so users can find a rule by what
    /// it does as well as by what it's called.
    private func applySearch(_ rules: [RuleRecord]) -> [RuleRecord] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rules }
        let lower = q.lowercased()
        return rules.filter { record in
            if record.name.lowercased().contains(lower) { return true }
            let trigger = RuleDisplay.triggerSentence(record.spec).lowercased()
            if trigger.contains(lower) { return true }
            let action = RuleDisplay.actionSentence(record.spec).lowercased()
            if action.contains(lower) { return true }
            return false
        }
    }

    /// iOS 快捷指令-style category color: each trigger family gets
    /// its own accent so a glance at the list shows the mix of
    /// time-based vs location-based vs state-based automations.
    private func triggerAccent(for record: RuleRecord) -> Color {
        let triggerType = record.spec["trigger"]?.objectValue?.string("type") ?? ""
        switch triggerType {
        case "cron":              return .blue        // time-based
        case "geofence":          return .green       // location-based
        case "state_transition":  return .indigo      // state event
        case "state_duration":
            // Sub-tint by the action's intent: low_battery (red/orange),
            // unlocked / closures (orange — security), camp/sentry/cabin
            // (purple/pink — comfort).
            let entity = record.spec["trigger"]?.objectValue?.string("entity") ?? ""
            switch entity {
            case "vehicle.battery_level":               return .orange
            case "vehicle.parked_unlocked",
                 "vehicle.parked_with_door_open",
                 "vehicle.parked_with_window_open",
                 "vehicle.parked_with_frunk_open",
                 "vehicle.parked_with_trunk_open":      return .orange
            case "vehicle.sentry_mode_on":              return .purple
            case "vehicle.cabin_overheat_protection_on": return .red
            case "vehicle.climate.keeper_mode":         return .purple
            default:                                    return .accentColor
            }
        default:                  return .accentColor
        }
    }

    private func triggerSummary(_ spec: RuleSpec) -> String {
        // Single source of truth — same string the rule detail view
        // uses, so list + detail can never drift.
        return RuleDisplay.triggerSentence(spec)
    }

    @ViewBuilder
    private func loadErrorSection(message: String) -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("加载规则失败")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await rulesStore.refresh() }
                } label: {
                    Label("重试", systemImage: "arrow.clockwise")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint.opacity(0.6))
                Text("还没有自动化")
                    .font(.headline)
                Text("从预设规则开始，或自己写一条新的。Tautomation 会用 Telemetry 实时车况监听，并在条件满足时推送通知。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showingBuilder = true
                } label: {
                    Label("新建自动化", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }

    /// Pre-populate the builder with a clone of `source` for the
    /// "复制为新规则" path. Empty id forces save → create.
    private func cloneForDuplicate(_ source: RuleRecord) -> RuleRecord {
        var nextName = "\(source.name) 副本"
        let existing = Set(rulesStore.rules.map(\.name))
        var i = 2
        while existing.contains(nextName) {
            nextName = "\(source.name) 副本 \(i)"
            i += 1
        }
        return RuleRecord(
            id: "",
            presetId: nil,
            name: nextName,
            enabled: source.enabled,
            spec: source.spec,
            version: 1
        )
    }

    /// Same wording as the detail page's "上次触发" — relative time
    /// in zh_CN locale.
    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Compact "HH:mm" or "明天 HH:mm" depending on whether the snooze
    /// crosses midnight from now. Used on the muted-rule badge.
    static func snoozeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(date) {
            f.dateFormat = "HH:mm"
            return f.string(from: date)
        }
        if cal.isDateInTomorrow(date) {
            f.dateFormat = "HH:mm"
            return "明天 " + f.string(from: date)
        }
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: date)
    }

    private func snoozeUntil(for ruleId: String) -> Date? {
        snoozeStore.activeUntil[ruleId]
    }

    @ViewBuilder
    private func snoozeMenu(for record: RuleRecord) -> some View {
        if snoozeUntil(for: record.id) != nil {
            Button {
                Task { await snoozeStore.unsnooze(ruleId: record.id) }
            } label: {
                Label("取消静音", systemImage: "bell.slash.fill")
            }
        } else {
            Menu {
                Button { snooze(record, hours: 1) } label: { Text("静音 1 小时") }
                Button { snooze(record, hours: 4) } label: { Text("静音 4 小时") }
                Button { snoozeUntilMorning(record) } label: { Text("静音至明早 8 点") }
            } label: {
                Label("静音", systemImage: "bell.slash")
            }
        }
    }

    private func snooze(_ record: RuleRecord, hours: Double) {
        Task { await snoozeStore.snooze(ruleId: record.id, hours: hours, reason: nil) }
    }

    private func snoozeUntilMorning(_ record: RuleRecord) {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        components.minute = 0
        var target = cal.date(from: components) ?? Date().addingTimeInterval(8 * 3600)
        if target <= Date() {
            target = cal.date(byAdding: .day, value: 1, to: target) ?? target
        }
        Task { await snoozeStore.snooze(ruleId: record.id, until: target, reason: nil) }
    }
}
