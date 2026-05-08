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
    @State private var showingBuilder = false
    @State private var workingError: String?
    @State private var pendingDelete: RuleRecord?
    @State private var pendingDuplicate: RuleRecord?
    @State private var searchText: String = ""

    private let apiService: APIServiceProtocol

    init(rulesStore: AutomationRulesStore, apiService: APIServiceProtocol) {
        self.rulesStore = rulesStore
        self.apiService = apiService
        _capabilitiesStore = StateObject(wrappedValue: CapabilitiesStore(apiService: apiService))
    }

    var body: some View {
        List {
            if rulesStore.rules.isEmpty && rulesStore.isLoading {
                Section { ProgressView("加载规则…") }
            }
            if !presetRules.isEmpty {
                Section("预设") {
                    ForEach(presetRules) { record in
                        ruleRow(record)
                    }
                    .onMove { from, to in
                        moveRules(in: presetRules, from: from, to: to)
                    }
                }
            }
            if !customRules.isEmpty {
                Section("我的自动化") {
                    ForEach(customRules) { record in
                        ruleRow(record)
                            .swipeActions {
                                Button(role: .destructive) {
                                    pendingDelete = record
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                    .onMove { from, to in
                        moveRules(in: customRules, from: from, to: to)
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
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
                    .accessibilityIdentifier("automations_edit_button")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingBuilder = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("automations_add_button")
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
    }

    @ViewBuilder
    private func ruleRow(_ record: RuleRecord) -> some View {
        NavigationLink {
            RuleDetailView(
                ruleId: record.id,
                rulesStore: rulesStore,
                capabilitiesStore: capabilitiesStore
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
            Button {
                pendingDuplicate = record
            } label: {
                Label("复制为新规则", systemImage: "plus.square.on.square")
            }
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
                if let last = record.lastFiredAt {
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
        applyUserOrder(applySearch(rulesStore.rules.filter { $0.presetId != nil }))
    }

    private var customRules: [RuleRecord] {
        applyUserOrder(applySearch(rulesStore.rules.filter { $0.presetId == nil }))
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

    /// Apply the user's drag-reordered sequence on top of whatever
    /// canonical order the server returned. Rules not in the saved
    /// order array (e.g. newly added presets) fall back to the end
    /// in server order.
    private func applyUserOrder(_ rules: [RuleRecord]) -> [RuleRecord] {
        let savedOrder = UserDefaultsSettingsStore.shared.automationRuleOrder
        guard !savedOrder.isEmpty else { return rules }
        let position = Dictionary(uniqueKeysWithValues: savedOrder.enumerated().map { ($1, $0) })
        let fallback = position.count
        return rules.enumerated().sorted { lhs, rhs in
            let lp = position[lhs.element.id] ?? (fallback + lhs.offset)
            let rp = position[rhs.element.id] ?? (fallback + rhs.offset)
            return lp < rp
        }.map(\.element)
    }

    /// Persist a drag-reorder by writing the new sequence of rule IDs
    /// to SettingsStore. Mutates the on-screen subset only — preset
    /// reorder doesn't affect custom rule positions and vice versa.
    private func moveRules(
        in section: [RuleRecord],
        from offsets: IndexSet,
        to destination: Int,
    ) {
        var working = section
        working.move(fromOffsets: offsets, toOffset: destination)
        // Rebuild the global order with this section's new sequence
        // in place; preserve the other section's relative ordering.
        let isPreset = (section.first?.presetId != nil)
        let other = isPreset ? customRules : presetRules
        let newOrder = working.map(\.id) + other.map(\.id)
        UserDefaultsSettingsStore.shared.automationRuleOrder = newOrder
        // Force a view refresh by tickling the rules store. Cheapest
        // way without adding @State for this.
        Task { await rulesStore.refresh() }
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
}
