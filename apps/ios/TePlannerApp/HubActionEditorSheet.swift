import SwiftUI
import TePlannerKit

/// Create-or-edit sheet for a HubAction. Multi-step macros: each
/// step picks a capability (reusing the capability picker pattern
/// from RuleBuilderView) + edits params via CapabilityParamEditor.
/// Inter-step delay (ms) is optional; only shown between steps.
struct HubActionEditorSheet: View {
    @ObservedObject var store: HubActionsStore
    /// nil = creating a new action; non-nil = editing existing.
    let editing: HubAction?
    /// Vehicle hardware facts for capability gating (e.g. hide
    /// sun_roof_* on a Model Y). nil = no gating.
    var vehicleConfig: VehicleConfig? = nil
    /// When creating from a tap on an empty slot, fill it on save.
    var slotToFill: Int? = nil
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var capStore: CapabilitiesStore = CapabilitiesStore(apiService: APIService.shared)

    // Editable state
    @State private var name: String = ""
    @State private var icon: String = "bolt.fill"
    @State private var tint: HubActionTint = .default
    @State private var steps: [HubActionStep] = []
    @State private var confirmRequired: Bool = false

    @State private var showingIconPicker: Bool = false
    @State private var showingDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                metaSection
                stepsSection
                confirmSection
                if editing?.isSystem == false {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Text("删除此动作").frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("hub_action_editor_delete")
                    }
                }
            }
            .navigationTitle(editing == nil ? "新建动作" : "编辑动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { onDone() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { Task { await save() } }
                        .disabled(!isValid)
                        .accessibilityIdentifier("hub_action_editor_save")
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                HubIconPickerSheet(selectedIcon: $icon, onDismiss: { showingIconPicker = false })
            }
            .alert("删除此动作？", isPresented: $showingDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let id = editing?.id {
                        Task {
                            await store.delete(id: id)
                            onDone()
                        }
                    }
                }
            } message: {
                Text("如果它被分配在某个槽位，槽位会被清空。")
            }
            .task {
                await capStore.refreshIfNeeded()
                if let e = editing {
                    name = e.name
                    icon = e.icon
                    tint = e.tint
                    steps = e.steps
                    confirmRequired = e.confirmRequired
                } else if steps.isEmpty {
                    // Seed with one empty step so the user sees the
                    // capability picker without having to tap "+" first.
                    steps = [HubActionStep(capability: "")]
                }
            }
        }
    }

    // MARK: - Sections

    private var metaSection: some View {
        Section("基本") {
            TextField("动作名称（最多 6 字）", text: $name)
                .textInputAutocapitalization(.never)
                .onChange(of: name) { _, newValue in
                    // Soft cap — Hub tiles wrap awkwardly above 6 chars.
                    if newValue.count > 6 {
                        name = String(newValue.prefix(6))
                    }
                }
                .accessibilityIdentifier("hub_action_editor_name")
            HStack {
                Text("图标")
                Spacer()
                Button {
                    showingIconPicker = true
                } label: {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(tintColor(tint))
                }
                .accessibilityIdentifier("hub_action_editor_icon")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("颜色")
                HStack(spacing: 14) {
                    ForEach(HubActionTint.allCases, id: \.self) { t in
                        Button {
                            tint = t
                        } label: {
                            Circle()
                                .fill(tintColor(t))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: tint == t ? 3 : 0)
                                )
                                .tokenShadow(Tokens.shadowSubtle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("hub_action_editor_tint_\(t.rawValue)")
                    }
                }
            }
        }
    }

    private var stepsSection: some View {
        Section {
            ForEach(steps.indices, id: \.self) { idx in
                stepCard(idx: idx)
            }
            .onDelete { offsets in
                steps.remove(atOffsets: offsets)
                if steps.isEmpty {
                    // Always keep at least one row so the user can
                    // still see the picker; on save, empty-capability
                    // steps are filtered out, so this is purely UI.
                    steps = [HubActionStep(capability: "")]
                }
            }
            if steps.count < 5 {
                Button {
                    steps.append(HubActionStep(capability: ""))
                } label: {
                    Label("添加步骤", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("hub_action_editor_add_step")
            }
        } header: {
            Text("执行步骤")
        } footer: {
            Text("一个按钮可以串联最多 5 步（按顺序执行）。")
        }
    }

    @ViewBuilder
    private func stepCard(idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("第 \(idx + 1) 步")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            capabilityPicker(stepIdx: idx)
            if !steps[idx].capability.isEmpty {
                CapabilityParamEditor(
                    capabilityId: steps[idx].capability,
                    paramOverrides: Binding(
                        get: { steps[idx].params },
                        set: { newParams in
                            let s = steps[idx]
                            steps[idx] = HubActionStep(
                                capability: s.capability,
                                params: newParams,
                                delayMsAfter: s.delayMsAfter,
                            )
                        }
                    )
                )
            }
            if idx < steps.count - 1 {
                HStack {
                    Text("执行后等待")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper(value: Binding(
                        get: { (steps[idx].delayMsAfter ?? 0) / 1000 },
                        set: { newSec in
                            let s = steps[idx]
                            steps[idx] = HubActionStep(
                                capability: s.capability,
                                params: s.params,
                                delayMsAfter: newSec > 0 ? newSec * 1000 : nil,
                            )
                        }
                    ), in: 0...30, step: 1) {
                        Text("\((steps[idx].delayMsAfter ?? 0) / 1000) 秒")
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("hub_action_editor_delay_\(idx)")
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func capabilityPicker(stepIdx: Int) -> some View {
        let buckets = sortedCapabilityBuckets()
        let currentCap = steps[stepIdx].capability
        Menu {
            ForEach(buckets, id: \.0) { (category, caps) in
                Section(category.label) {
                    ForEach(caps) { cap in
                        Button {
                            updateStep(idx: stepIdx, capability: cap.id)
                        } label: {
                            Label(RuleDisplay.capabilityName(cap.id), systemImage: category.symbol)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("操作")
                Spacer()
                Text(currentCap.isEmpty ? "选择操作" : RuleDisplay.capabilityName(currentCap))
                    .foregroundStyle(currentCap.isEmpty ? .secondary : .primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityIdentifier("hub_action_editor_capability_\(stepIdx)")
    }

    private func updateStep(idx: Int, capability: String) {
        guard steps.indices.contains(idx) else { return }
        // When the capability changes, seed the default params for
        // the new capability so the user doesn't have to fill the
        // whole form from scratch.
        let defaults = CapabilityDefaults.params[capability] ?? [:]
        steps[idx] = HubActionStep(
            capability: capability,
            params: defaults,
            delayMsAfter: steps[idx].delayMsAfter,
        )
    }

    private func sortedCapabilityBuckets()
        -> [(RuleDisplay.CapabilityCategory, [CapabilityInfo])]
    {
        var byCategory: [RuleDisplay.CapabilityCategory: [CapabilityInfo]] = [:]
        for cap in capStore.capabilities
            where !RuleDisplay.isHiddenInPicker(cap.id, vehicleConfig: vehicleConfig)
        {
            byCategory[RuleDisplay.capabilityCategory(cap.id), default: []].append(cap)
        }
        return RuleDisplay.CapabilityCategory.allCases.compactMap { cat in
            guard let arr = byCategory[cat], !arr.isEmpty else { return nil }
            let sorted = arr.sorted {
                RuleDisplay.capabilityName($0.id) < RuleDisplay.capabilityName($1.id)
            }
            return (cat, sorted)
        }
    }

    private var confirmSection: some View {
        Section {
            Toggle("执行前需要确认", isOn: $confirmRequired)
                .accessibilityIdentifier("hub_action_editor_confirm")
        } footer: {
            Text("对解锁、启动空调等敏感动作建议保持开启。")
        }
    }

    // MARK: - Validation + save

    private var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let validSteps = steps.filter { !$0.capability.isEmpty }
        return !validSteps.isEmpty
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Drop any "empty capability" placeholder rows the user
        // added but never picked an operation for. UI also disables
        // Save when this would result in zero steps, but defend in
        // depth.
        let validSteps = steps.filter { !$0.capability.isEmpty }
        guard !validSteps.isEmpty else { return }

        if let e = editing {
            await store.update(
                id: e.id,
                name: trimmed,
                icon: icon,
                tint: tint,
                steps: validSteps,
                confirmRequired: confirmRequired,
            )
        } else {
            let newId = await store.create(
                name: trimmed,
                icon: icon,
                tint: tint,
                steps: validSteps,
                confirmRequired: confirmRequired,
                assignToFirstEmpty: slotToFill == nil,
            )
            if let slot = slotToFill {
                await store.assignSlot(index: slot, actionId: newId)
            }
        }
        onDone()
    }

    private func tintColor(_ tint: HubActionTint) -> Color {
        switch tint {
        case .blue: return .blue
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .gray: return .gray
        }
    }
}
