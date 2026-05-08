import SwiftUI
import TePlannerKit

/// Phase 10.3.C — visual rule authoring canvas. Apple Shortcuts /
/// Home Assistant style: pick trigger, pick action, save. v1
/// limitations (per the approved plan):
///   - exactly 1 trigger
///   - 0 conditions (UI placeholder; AND-logic comes in 10.3.D)
///   - 1 action only (sequence of multiple actions = future)
///   - capability picker filters by safety class; .security needs
///     "我已知道" toggle before saving the rule
struct RuleBuilderView: View {
    let initial: RuleRecord?
    @ObservedObject var rulesStore: AutomationRulesStore
    @ObservedObject var capabilitiesStore: CapabilitiesStore

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var enabled: Bool = true

    @State private var triggerType: TriggerType = .stateDuration
    @State private var entity: VehicleEntity = .climateKeeperMode
    @State private var compareValueInt: Int = 3
    @State private var compareValueBool: Bool = true
    @State private var forMinutes: Int = 60
    @State private var toString: String = "Complete"

    @State private var actionType: ActionType = .notify
    @State private var actionTitle: String = ""
    @State private var actionBody: String = ""
    @State private var actionSeverity: AlertSeverityChoice = .info
    @State private var primaryActionLabel: String = ""
    @State private var selectedCapabilityId: String = ""
    @State private var paramOverrides: [String: JSONValue] = [:]
    @State private var unsafeAcknowledged = false

    @State private var startFromPresetSheet = false
    @State private var saving = false
    @State private var saveError: String?

    enum TriggerType: String, CaseIterable, Identifiable {
        case stateDuration = "state_duration"
        case stateTransition = "state_transition"
        var id: String { rawValue }
        var label: String {
            self == .stateDuration ? "持续状态" : "状态变化"
        }
    }

    enum VehicleEntity: String, CaseIterable, Identifiable {
        case climateKeeperMode = "vehicle.climate.keeper_mode"
        case sentryModeOn = "vehicle.sentry_mode_on"
        case cabinOverheatOn = "vehicle.cabin_overheat_protection_on"
        case chargingState = "vehicle.charging.state"
        case batteryLevel = "vehicle.battery_level"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .climateKeeperMode: return "空调保持模式"
            case .sentryModeOn:      return "哨兵模式"
            case .cabinOverheatOn:   return "座舱过热保护"
            case .chargingState:     return "充电状态"
            case .batteryLevel:      return "电量百分比"
            }
        }
        var valueKind: ValueKind {
            switch self {
            case .climateKeeperMode, .batteryLevel: return .int
            case .sentryModeOn, .cabinOverheatOn:    return .bool
            case .chargingState:                     return .string
            }
        }
        enum ValueKind { case int, bool, string }
    }

    enum ActionType: String, CaseIterable, Identifiable {
        case notify = "notify"
        case notifyAndOffer = "notify_and_offer"
        var id: String { rawValue }
        var label: String {
            self == .notify ? "仅通知" : "通知 + 操作按钮"
        }
    }

    enum AlertSeverityChoice: String, CaseIterable, Identifiable {
        case info, critical
        var id: String { rawValue }
        var label: String {
            self == .info ? "信息" : "严重"
        }
    }

    var body: some View {
        Form {
            metaSection
            triggerSection
            actionSection
            unsafeSection
            saveSection
        }
        .navigationTitle(initial == nil ? "新建自动化" : "编辑自动化")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") { dismiss() }
            }
            if initial == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("从预设") { startFromPresetSheet = true }
                }
            }
        }
        .sheet(isPresented: $startFromPresetSheet) {
            PresetPickerSheet { selected in
                fillFromPreset(selected)
                startFromPresetSheet = false
            }
        }
        .onAppear { hydrateFromInitialIfPresent() }
    }

    // MARK: - Sections

    private var metaSection: some View {
        Section("名称") {
            TextField("起一个好记的名字", text: $name)
                .accessibilityIdentifier("rule_name_field")
            Toggle("启用", isOn: $enabled)
        }
    }

    private var triggerSection: some View {
        Section("触发条件 · 当") {
            Picker("类型", selection: $triggerType) {
                ForEach(TriggerType.allCases) { t in
                    Text(t.label).tag(t)
                }
            }
            Picker("观察项", selection: $entity) {
                ForEach(VehicleEntity.allCases) { e in
                    Text(e.label).tag(e)
                }
            }
            switch triggerType {
            case .stateDuration:
                stateDurationValueRow
                Stepper(
                    value: $forMinutes,
                    in: 1...4320,
                    step: 30
                ) {
                    HStack {
                        Text("持续时长")
                        Spacer()
                        Text(formatMinutes(forMinutes))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            case .stateTransition:
                TextField("目标值", text: $toString)
                    .textInputAutocapitalization(.never)
            }
        }
    }

    @ViewBuilder
    private var stateDurationValueRow: some View {
        switch entity.valueKind {
        case .int:
            Stepper(
                value: $compareValueInt,
                in: 0...100
            ) {
                HStack {
                    Text("等于")
                    Spacer()
                    Text("\(compareValueInt)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        case .bool:
            Toggle("等于真", isOn: $compareValueBool)
        case .string:
            TextField("等于（字符串）", text: $toString)
                .textInputAutocapitalization(.never)
        }
    }

    private var actionSection: some View {
        Section("动作 · 那么") {
            Picker("类型", selection: $actionType) {
                ForEach(ActionType.allCases) { a in
                    Text(a.label).tag(a)
                }
            }
            TextField("标题（推送通知）", text: $actionTitle)
                .accessibilityIdentifier("rule_action_title_field")
            TextField("正文（{duration_human} 等占位符可用）", text: $actionBody, axis: .vertical)
                .lineLimit(2...5)
            Picker("级别", selection: $actionSeverity) {
                ForEach(AlertSeverityChoice.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            if actionType == .notifyAndOffer {
                TextField("按钮文字", text: $primaryActionLabel)
                Picker("点击按钮后执行", selection: $selectedCapabilityId) {
                    Text("仅关闭提醒").tag("")
                    ForEach(capabilitiesStore.capabilities) { cap in
                        Text(RuleDisplay.capabilityName(cap.id)).tag(cap.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var unsafeSection: some View {
        if let cap = capabilitiesStore.get(selectedCapabilityId), cap.safetyClass != .read, cap.safetyClass != .writable {
            Section {
                Toggle(
                    "我已知道：此 capability 是 \(cap.safetyClass.rawValue) 级别，触发后可能影响车辆安全状态",
                    isOn: $unsafeAcknowledged
                )
                .tint(.orange)
            }
        }
    }

    private var saveSection: some View {
        Section {
            if let err = saveError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            Button {
                Task { await save() }
            } label: {
                Text(saving ? "保存中…" : "保存")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid || saving)
            .accessibilityIdentifier("rule_save_button")
        }
    }

    // MARK: - Data plumbing

    private var isValid: Bool {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if actionTitle.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if actionBody.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if actionType == .notifyAndOffer && primaryActionLabel.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        if let cap = capabilitiesStore.get(selectedCapabilityId),
           cap.safetyClass != .read, cap.safetyClass != .writable,
           !unsafeAcknowledged {
            return false
        }
        return true
    }

    private func hydrateFromInitialIfPresent() {
        guard let r = initial else { return }
        name = r.name
        enabled = r.enabled
        let spec = r.spec
        if let trigger = spec["trigger"]?.objectValue {
            if let t = trigger.string("type"),
               let parsed = TriggerType(rawValue: t) {
                triggerType = parsed
            }
            if let e = trigger.string("entity"),
               let parsed = VehicleEntity(rawValue: e) {
                entity = parsed
            }
            if let v = trigger["equals"] {
                if let i = v.intValue { compareValueInt = i }
                if let b = v.boolValue { compareValueBool = b }
                if let s = v.stringValue { toString = s }
            }
            if let mins = trigger.int("for_minutes") { forMinutes = mins }
            if let target = trigger.string("to") { toString = target }
        }
        // Pull first action.
        let candidates: [String] = ["actions_above", "actions"]
        for key in candidates {
            if case .array(let arr) = spec[key] ?? .null,
               let first = arr.first?.objectValue {
                if let t = first.string("type"), let parsed = ActionType(rawValue: t) {
                    actionType = parsed
                }
                actionTitle = first.string("title") ?? ""
                actionBody = first.string("body") ?? ""
                if let s = first.string("severity"), let parsed = AlertSeverityChoice(rawValue: s) {
                    actionSeverity = parsed
                }
                primaryActionLabel = first.string("primary_action_label") ?? ""
                selectedCapabilityId = first.string("capability") ?? ""
                if let p = first["params"]?.objectValue {
                    paramOverrides = p
                }
                break
            }
        }
    }

    private func fillFromPreset(_ preset: RuleRecord) {
        name = preset.name
        enabled = true
        // Re-use the hydration logic.
        let snapshot = preset
        // Save current `initial` workaround — call hydrate directly.
        let spec = snapshot.spec
        if let trigger = spec["trigger"]?.objectValue {
            if let t = trigger.string("type"), let parsed = TriggerType(rawValue: t) {
                triggerType = parsed
            }
            if let e = trigger.string("entity"), let parsed = VehicleEntity(rawValue: e) {
                entity = parsed
            }
            if let v = trigger["equals"] {
                if let i = v.intValue { compareValueInt = i }
                if let b = v.boolValue { compareValueBool = b }
                if let s = v.stringValue { toString = s }
            }
            if let mins = trigger.int("for_minutes") { forMinutes = mins }
            if let target = trigger.string("to") { toString = target }
        }
        let candidates: [String] = ["actions_above", "actions"]
        for key in candidates {
            if case .array(let arr) = spec[key] ?? .null,
               let first = arr.first?.objectValue {
                if let t = first.string("type"), let parsed = ActionType(rawValue: t) {
                    actionType = parsed
                }
                actionTitle = first.string("title") ?? ""
                actionBody = first.string("body") ?? ""
                if let s = first.string("severity"), let parsed = AlertSeverityChoice(rawValue: s) {
                    actionSeverity = parsed
                }
                primaryActionLabel = first.string("primary_action_label") ?? ""
                selectedCapabilityId = first.string("capability") ?? ""
                if let p = first["params"]?.objectValue { paramOverrides = p }
                break
            }
        }
    }

    private func buildSpec() -> RuleSpec {
        let kindString = inferKind()
        var trigger: [String: JSONValue] = [
            "type": .string(triggerType.rawValue),
            "entity": .string(entity.rawValue),
        ]
        switch triggerType {
        case .stateDuration:
            switch entity.valueKind {
            case .int:    trigger["equals"] = .int(compareValueInt)
            case .bool:   trigger["equals"] = .bool(compareValueBool)
            case .string: trigger["equals"] = .string(toString)
            }
            trigger["for_minutes"] = .int(forMinutes)
            trigger["state_key"] = .string("user:\(kindString):startedAt")
        case .stateTransition:
            trigger["to"] = .string(toString)
            trigger["first_seen_key"] = .string("user:\(kindString):firstSeenAt")
            trigger["dismissed_key"] = .string("user:\(kindString):dismissedAt")
            trigger["reset_when_not_to"] = .bool(true)
        }

        var action: [String: JSONValue] = [
            "type": .string(actionType.rawValue),
            "title": .string(actionTitle),
            "body": .string(actionBody),
            "severity": .string(actionSeverity.rawValue),
        ]
        if actionType == .notifyAndOffer {
            action["primary_action_label"] = .string(primaryActionLabel)
            if !selectedCapabilityId.isEmpty {
                action["capability"] = .string(selectedCapabilityId)
                if !paramOverrides.isEmpty {
                    action["params"] = .object(paramOverrides)
                }
            } else {
                action["capability"] = .string("automation.dismiss")
            }
        }

        var spec: RuleSpec = [
            "kind": .string(kindString),
            "trigger": .object(trigger),
        ]
        switch triggerType {
        case .stateDuration:
            spec["actions_above"] = .array([.object(action)])
            spec["actions_below"] = .array([])
        case .stateTransition:
            spec["actions"] = .array([.object(action)])
        }
        return spec
    }

    private func inferKind() -> String {
        // Map entity to a known kind for backward-compatibility with
        // the four AlertKind enum values. Custom rules built from
        // scratch fall through to the entity-derived synthetic kind
        // so the engine still routes pushes correctly.
        switch entity {
        case .climateKeeperMode: return "campMode"
        case .sentryModeOn:      return "sentryMode"
        case .cabinOverheatOn:   return "cabinOverheat"
        case .chargingState:     return "chargeComplete"
        case .batteryLevel:      return "campMode" // fallback
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let spec = buildSpec()
        if let r = initial {
            let ok = await rulesStore.update(id: r.id, name: name, enabled: enabled, spec: spec)
            if ok { dismiss() } else { saveError = rulesStore.lastError }
        } else {
            let new = await rulesStore.create(name: name, enabled: enabled, spec: spec)
            if new != nil { dismiss() } else { saveError = rulesStore.lastError }
        }
    }

    private func formatMinutes(_ m: Int) -> String {
        if m < 60 { return "\(m) 分钟" }
        let h = m / 60
        let r = m % 60
        return r == 0 ? "\(h) 小时" : "\(h) 小时 \(r) 分钟"
    }
}

/// Sheet that lets the user pick one of the 4 hardcoded presets to
/// pre-fill the builder with. Replaces the "templates first" UI from
/// the plan — same effect, lives inside the builder.
private struct PresetPickerSheet: View {
    let onSelect: (RuleRecord) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(PresetSpecs.allPresets) { preset in
                Button {
                    onSelect(preset)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.name).foregroundStyle(.primary)
                        Text(preset.presetId ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("从预设开始")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
