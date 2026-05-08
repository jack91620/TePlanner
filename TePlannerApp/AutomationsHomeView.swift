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
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: iconName(for: record))
                    .foregroundStyle(record.enabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.name)
                        .foregroundStyle(.primary)
                    Text(triggerSummary(record.spec))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
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

    private func iconName(for record: RuleRecord) -> String {
        switch record.spec.string("kind") {
        case "campMode": return "tent.fill"
        case "sentryMode": return "shield.fill"
        case "cabinOverheat": return "thermometer.sun.fill"
        case "chargeComplete": return "bolt.batteryblock.fill"
        case "leftUnlocked": return "lock.open.fill"
        case "closureLeftOpen": return "door.left.hand.open"
        case "lowBattery": return "battery.25"
        default: return "bell.badge.fill"
        }
    }

    private func triggerSummary(_ spec: RuleSpec) -> String {
        guard let trigger = spec["trigger"]?.objectValue,
              let type = trigger.string("type") else {
            return ""
        }
        switch type {
        case "state_duration":
            let entity = RuleDisplay.entityName(trigger.string("entity") ?? "")
            let mins = trigger.int("for_minutes") ?? 0
            return "\(entity) 持续 \(RuleDisplay.formatDurationMinutes(mins))"
        case "state_transition":
            let entity = RuleDisplay.entityName(trigger.string("entity") ?? "")
            let target = trigger.string("to") ?? "?"
            return "\(entity) → \(target)"
        case "cron":
            return "定时: \(trigger.string("expr") ?? "")"
        default:
            return type
        }
    }
}
