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
    @State private var numericOp: NumericOp = .lt
    @State private var numericValue: Int = 30
    // Slice C — cron trigger state. cronWeekdays uses ISO numbers
    // (1..7 Mon..Sun) to match croniter's default; we render as
    // 周一..周日 in the chips.
    @State private var cronHour: Int = 7
    @State private var cronMinute: Int = 30
    @State private var cronWeekdays: Set<Int> = [1, 2, 3, 4, 5]

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
        case cron = "cron"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .stateDuration:   return "持续状态"
            case .stateTransition: return "状态变化"
            case .cron:            return "定时"
            }
        }
        var symbol: String {
            switch self {
            case .stateDuration:   return "timer"
            case .stateTransition: return "arrow.right.arrow.left.circle.fill"
            case .cron:            return "clock.fill"
            }
        }
        var description: String {
            switch self {
            case .stateDuration:
                return "某个状态持续超过设定时长（露营 2 小时、解锁 5 分钟…）"
            case .stateTransition:
                return "状态发生变化（充电完成、车辆上线…）"
            case .cron:
                return "按时间触发（每个工作日 7:30、每天晚上…）"
            }
        }
        var accent: Color {
            switch self {
            case .stateDuration:   return .indigo
            case .stateTransition: return .purple
            case .cron:            return .blue
            }
        }
    }

    enum VehicleEntity: String, CaseIterable, Identifiable {
        case climateKeeperMode = "vehicle.climate.keeper_mode"
        case sentryModeOn = "vehicle.sentry_mode_on"
        case cabinOverheatOn = "vehicle.cabin_overheat_protection_on"
        case chargingState = "vehicle.charging.state"
        // Slice A — closure / lock virtual entities. They embed
        // "停车后" so users can build "锁车忘了" rules without worrying
        // about driving false-positives.
        case parkedUnlocked = "vehicle.parked_unlocked"
        case parkedWithDoorOpen = "vehicle.parked_with_door_open"
        case parkedWithWindowOpen = "vehicle.parked_with_window_open"
        case parkedWithFrunkOpen = "vehicle.parked_with_frunk_open"
        case parkedWithTrunkOpen = "vehicle.parked_with_trunk_open"
        // Slice B — numeric (uses comparator picker)
        case batteryLevel = "vehicle.battery_level"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .climateKeeperMode:    return "露营/宠物/保持模式"
            case .sentryModeOn:         return "哨兵模式"
            case .cabinOverheatOn:      return "座舱过热保护"
            case .chargingState:        return "充电状态"
            case .parkedUnlocked:       return "停车后未锁车"
            case .parkedWithDoorOpen:   return "停车后车门开"
            case .parkedWithWindowOpen: return "停车后车窗开"
            case .parkedWithFrunkOpen:  return "停车后前备箱开"
            case .parkedWithTrunkOpen:  return "停车后后备箱开"
            case .batteryLevel:         return "电量百分比"
            }
        }
        var valueKind: ValueKind {
            switch self {
            case .climateKeeperMode: return .keeperMode
            case .sentryModeOn, .cabinOverheatOn,
                 .parkedUnlocked, .parkedWithDoorOpen,
                 .parkedWithWindowOpen, .parkedWithFrunkOpen,
                 .parkedWithTrunkOpen: return .bool
            case .chargingState:     return .string
            case .batteryLevel:      return .numeric
            }
        }
        enum ValueKind { case keeperMode, bool, string, numeric }
    }

    /// Comparator for numeric entities. Backend reads as `op` field.
    enum NumericOp: String, CaseIterable, Identifiable {
        case lt = "<"
        case lte = "<="
        case eq = "=="
        case gte = ">="
        case gt = ">"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .lt:  return "低于"
            case .lte: return "不超过"
            case .eq:  return "等于"
            case .gte: return "不低于"
            case .gt:  return "高于"
            }
        }
    }

    /// 4 个 keeper_mode int 值 + 用户友好标签。
    enum KeeperModeChoice: Int, CaseIterable, Identifiable {
        case off = 0, keep = 1, dog = 2, camp = 3
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .off:  return "关闭"
            case .keep: return "保持"
            case .dog:  return "宠物模式"
            case .camp: return "露营模式"
            }
        }
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
        Section {
            TextField("起一个好记的名字", text: $name)
                .accessibilityIdentifier("rule_name_field")
            Toggle("启用", isOn: $enabled)
        } header: {
            HStack(spacing: 4) {
                Text("名称")
                Text("*").foregroundStyle(.red)
            }
        }
    }

    /// iOS 快捷指令-style trigger type selector: 3 cards in a row,
    /// each showing the trigger family's icon, label, and a one-liner
    /// of what kind of rule it builds. The selected card gets a tinted
    /// background; tapping a card switches the trigger type.
    @ViewBuilder
    private var triggerTypePicker: some View {
        VStack(spacing: 8) {
            ForEach(TriggerType.allCases) { t in
                Button {
                    triggerType = t
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(t.accent.opacity(triggerType == t ? 0.25 : 0.10))
                            Image(systemName: t.symbol)
                                .foregroundStyle(t.accent)
                        }
                        .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(t.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 4)
                        if triggerType == t {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(t.accent)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var triggerSection: some View {
        Section("当") {
            triggerTypePicker
            switch triggerType {
            case .stateDuration:
                Picker("观察项", selection: $entity) {
                    ForEach(VehicleEntity.allCases) { e in
                        Text(e.label).tag(e)
                    }
                }
                stateDurationValueRow
                Stepper(value: $forMinutes, in: 1...4320, step: 30) {
                    HStack {
                        Text("持续时长")
                        Spacer()
                        Text(formatMinutes(forMinutes))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            case .stateTransition:
                Picker("观察项", selection: $entity) {
                    ForEach(VehicleEntity.allCases) { e in
                        Text(e.label).tag(e)
                    }
                }
                TextField("目标值", text: $toString)
                    .textInputAutocapitalization(.never)
            case .cron:
                cronEditor
            }
        }
    }

    @ViewBuilder
    private var cronEditor: some View {
        // 时间
        let timeBinding = Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = cronHour
                components.minute = cronMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let comp = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                cronHour = comp.hour ?? 0
                cronMinute = comp.minute ?? 0
            }
        )
        DatePicker("时间", selection: timeBinding, displayedComponents: .hourAndMinute)

        // 重复日 — multi-select chips. ISO 1..7 = Mon..Sun.
        VStack(alignment: .leading, spacing: 8) {
            Text("重复").font(.subheadline)
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    let label = ["一", "二", "三", "四", "五", "六", "日"][day - 1]
                    let on = cronWeekdays.contains(day)
                    Text("周\(label)")
                        .font(.caption)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(on ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .onTapGesture {
                            if on { cronWeekdays.remove(day) }
                            else { cronWeekdays.insert(day) }
                        }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var stateDurationValueRow: some View {
        switch entity.valueKind {
        case .keeperMode:
            Picker("状态", selection: $compareValueInt) {
                ForEach(KeeperModeChoice.allCases) { choice in
                    Text(choice.label).tag(choice.rawValue)
                }
            }
        case .bool:
            // 哨兵 / 座舱过热只有「开/关」两态。Picker 比 Toggle 更直观，
            // 因为「等于真」用户读起来不像句子。
            Picker("状态", selection: $compareValueBool) {
                Text("开启").tag(true)
                Text("关闭").tag(false)
            }
        case .string:
            TextField("等于（字符串）", text: $toString)
                .textInputAutocapitalization(.never)
        case .numeric:
            // Slice B — comparator + threshold for entities like
            // battery_level. Step by 5 because 1% precision is
            // overkill for "提醒我电量低".
            Picker("比较", selection: $numericOp) {
                ForEach(NumericOp.allCases) { op in
                    Text(op.label).tag(op)
                }
            }
            Stepper(value: $numericValue, in: 0...100, step: 5) {
                HStack {
                    Text("阈值")
                    Spacer()
                    Text("\(numericValue)%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var actionSection: some View {
        Section {
            Picker("类型", selection: $actionType) {
                ForEach(ActionType.allCases) { a in
                    Text(a.label).tag(a)
                }
            }
            HStack(spacing: 0) {
                TextField("标题（推送通知）", text: $actionTitle)
                    .accessibilityIdentifier("rule_action_title_field")
                if actionTitle.isEmpty {
                    Text("*").foregroundStyle(.red).font(.footnote)
                }
            }
            HStack(alignment: .top, spacing: 0) {
                TextField("正文", text: $actionBody, axis: .vertical)
                    .lineLimit(2...5)
                if actionBody.isEmpty {
                    Text("*").foregroundStyle(.red).font(.footnote)
                }
            }
            if !bodyPreview.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "eye")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("用户看到：\(bodyPreview)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
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
        } header: {
            Text("那么")
        } footer: {
            Text("可在正文里插入 {duration_human}（持续时长）或 {battery_level}（当前电量）等占位符，推送时会自动替换成真实值。")
                .font(.caption2)
        }
    }

    /// Realtime preview of the body with placeholders rendered using
    /// the spec's current threshold. Helps users understand what a
    /// preset's `{duration_human}` placeholder turns into without
    /// reading docs.
    private var bodyPreview: String {
        guard !actionBody.isEmpty else { return "" }
        // Build a minimal trigger spec snapshot just enough to fill
        // the standard placeholders.
        var spec: RuleSpec = ["trigger": .object(["for_minutes": .int(forMinutes)])]
        spec["kind"] = .string("preview")
        let rendered = RuleDisplay.previewTemplate(actionBody, spec: spec)
        // Avoid showing the preview if it's literally identical to
        // what the user typed (no placeholders in body).
        return rendered == actionBody ? "" : rendered
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
            if !isValid && missingFieldsHint != nil {
                Label(missingFieldsHint ?? "", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    /// Surface specifically WHAT's preventing save so the disabled
    /// button doesn't feel broken to the user.
    private var missingFieldsHint: String? {
        var missing: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("名称") }
        if actionTitle.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("标题") }
        if actionBody.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("正文") }
        if actionType == .notifyAndOffer
           && primaryActionLabel.trimmingCharacters(in: .whitespaces).isEmpty {
            missing.append("按钮文字")
        }
        if let cap = capabilitiesStore.get(selectedCapabilityId),
           cap.safetyClass != .read, cap.safetyClass != .writable,
           !unsafeAcknowledged {
            return "该动作涉及车辆安全状态，请勾选「我已知道」后保存"
        }
        guard !missing.isEmpty else { return nil }
        return "请填写：\(missing.joined(separator: " · "))"
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
            // Slice B — numeric op + threshold
            if let opString = trigger.string("op"),
               let parsedOp = NumericOp(rawValue: opString) {
                numericOp = parsedOp
            }
            if let val = trigger.int("value") { numericValue = val }
            if let mins = trigger.int("for_minutes") { forMinutes = mins }
            if let target = trigger.string("to") { toString = target }
            // Slice C — cron expr → time + weekdays
            if let expr = trigger.string("expr") {
                let parts = expr.split(separator: " ").map(String.init)
                if parts.count == 5,
                   let m = Int(parts[0]),
                   let h = Int(parts[1]) {
                    cronMinute = m
                    cronHour = h
                    let weekdayField = parts[4]
                    if weekdayField == "*" {
                        cronWeekdays = Set(1...7)
                    } else if weekdayField == "1-5" {
                        cronWeekdays = Set(1...5)
                    } else {
                        let nums = weekdayField
                            .split(separator: ",")
                            .compactMap { Int($0) }
                        cronWeekdays = Set(nums.filter { (1...7).contains($0) })
                    }
                }
            }
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
        // If the user already has a rule with this name (likely the
        // auto-seeded preset), suffix to disambiguate. Mirrors how
        // iOS 提醒事项 / Shortcuts handle duplicates.
        var nextName = preset.name
        let existing = Set(rulesStore.rules.map(\.name))
        if existing.contains(nextName) {
            var i = 2
            var candidate = "\(nextName) 副本"
            while existing.contains(candidate) {
                i += 1
                candidate = "\(nextName) 副本 \(i)"
            }
            nextName = candidate
        }
        name = nextName
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
            // Slice B — numeric op + threshold
            if let opString = trigger.string("op"),
               let parsedOp = NumericOp(rawValue: opString) {
                numericOp = parsedOp
            }
            if let val = trigger.int("value") { numericValue = val }
            if let mins = trigger.int("for_minutes") { forMinutes = mins }
            if let target = trigger.string("to") { toString = target }
            // Slice C — cron expr → time + weekdays
            if let expr = trigger.string("expr") {
                let parts = expr.split(separator: " ").map(String.init)
                if parts.count == 5,
                   let m = Int(parts[0]),
                   let h = Int(parts[1]) {
                    cronMinute = m
                    cronHour = h
                    let weekdayField = parts[4]
                    if weekdayField == "*" {
                        cronWeekdays = Set(1...7)
                    } else if weekdayField == "1-5" {
                        cronWeekdays = Set(1...5)
                    } else {
                        let nums = weekdayField
                            .split(separator: ",")
                            .compactMap { Int($0) }
                        cronWeekdays = Set(nums.filter { (1...7).contains($0) })
                    }
                }
            }
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
            case .keeperMode: trigger["equals"] = .int(compareValueInt)
            case .bool:       trigger["equals"] = .bool(compareValueBool)
            case .string:     trigger["equals"] = .string(toString)
            case .numeric:
                trigger["op"] = .string(numericOp.rawValue)
                trigger["value"] = .int(numericValue)
            }
            trigger["for_minutes"] = .int(forMinutes)
            trigger["state_key"] = .string("user:\(kindString):startedAt")
        case .stateTransition:
            trigger["to"] = .string(toString)
            trigger["first_seen_key"] = .string("user:\(kindString):firstSeenAt")
            trigger["dismissed_key"] = .string("user:\(kindString):dismissedAt")
            trigger["reset_when_not_to"] = .bool(true)
        case .cron:
            trigger.removeValue(forKey: "entity")
            trigger["expr"] = .string(cronExpression())
            trigger["tz"] = .string("Asia/Shanghai")
            trigger["last_fired_key"] = .string("user:\(kindString):lastFiredAt")
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
        case .stateTransition, .cron:
            spec["actions"] = .array([.object(action)])
        }
        return spec
    }

    private func inferKind() -> String {
        if triggerType == .cron { return "weekdayPreheat" }
        switch entity {
        case .climateKeeperMode:    return "campMode"
        case .sentryModeOn:         return "sentryMode"
        case .cabinOverheatOn:      return "cabinOverheat"
        case .chargingState:        return "chargeComplete"
        case .parkedUnlocked:       return "leftUnlocked"
        case .parkedWithDoorOpen,
             .parkedWithWindowOpen,
             .parkedWithFrunkOpen,
             .parkedWithTrunkOpen:  return "closureLeftOpen"
        case .batteryLevel:         return "lowBattery"
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

    /// Build a 5-field cron expression from the picker state.
    /// Backend uses croniter — supports comma-list weekdays (1,3,5)
    /// and ranges, but we just emit comma-separated for simplicity.
    private func cronExpression() -> String {
        let weekdayPart: String
        if cronWeekdays.count == 7 {
            weekdayPart = "*"
        } else if cronWeekdays.isEmpty {
            // Fallback to "every day" rather than emit invalid cron.
            weekdayPart = "*"
        } else {
            weekdayPart = cronWeekdays.sorted().map(String.init).joined(separator: ",")
        }
        return "\(cronMinute) \(cronHour) * * \(weekdayPart)"
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
                        Text(Self.presetSubtitle(preset))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

    /// Render a human description of what the preset does instead
    /// of leaking the internal preset_id (camp_mode_overstay etc.)
    /// to users.
    private static func presetSubtitle(_ preset: RuleRecord) -> String {
        let trigger = RuleDisplay.triggerSentence(preset.spec)
        return trigger.isEmpty ? "预设规则" : trigger
    }
}
