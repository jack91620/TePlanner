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
                }
            }
            if !customRules.isEmpty {
                Section("我的自动化") {
                    ForEach(customRules) { record in
                        ruleRow(record)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        let ok = await rulesStore.delete(id: record.id)
                                        if !ok { workingError = rulesStore.lastError }
                                    }
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
        .toolbar {
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
    }

    private var presetRules: [RuleRecord] {
        rulesStore.rules.filter { $0.presetId != nil }
    }

    private var customRules: [RuleRecord] {
        rulesStore.rules.filter { $0.presetId == nil }
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
}
