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
    /// Optional template to pre-fill the form with (used by "复制为
    /// 新规则" from RuleDetailView). Form fields hydrate from this on
    /// first appear; save() still creates a brand-new rule (because
    /// `initial` is nil in this path).
    let template: RuleRecord?
    @ObservedObject var rulesStore: AutomationRulesStore
    @ObservedObject var capabilitiesStore: CapabilitiesStore

    init(
        initial: RuleRecord?,
        template: RuleRecord? = nil,
        rulesStore: AutomationRulesStore,
        capabilitiesStore: CapabilitiesStore,
    ) {
        self.initial = initial
        self.template = template
        self.rulesStore = rulesStore
        self.capabilitiesStore = capabilitiesStore
    }

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
    @State private var showingDeleteConfirm = false

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

        /// User-facing grouping for the picker — mirrors how
        /// `RuleDisplay.capabilityCategory` groups action capabilities.
        enum Category: String, CaseIterable {
            case climate, security, closures, charging, battery

            var label: String {
                switch self {
                case .climate:  return "空调"
                case .security: return "安全"
                case .closures: return "门窗"
                case .charging: return "充电"
                case .battery:  return "电量"
                }
            }
        }

        var category: Category {
            switch self {
            case .climateKeeperMode, .cabinOverheatOn: return .climate
            case .sentryModeOn, .parkedUnlocked:        return .security
            case .parkedWithDoorOpen, .parkedWithWindowOpen,
                 .parkedWithFrunkOpen, .parkedWithTrunkOpen: return .closures
            case .chargingState:                        return .charging
            case .batteryLevel:                         return .battery
            }
        }
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
        .confirmationDialog(
            "确定删除「\(initial?.name ?? "")」？",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible,
        ) {
            Button("删除", role: .destructive) {
                Task {
                    guard let r = initial else { return }
                    let ok = await rulesStore.delete(id: r.id)
                    if ok { dismiss() }
                    else { saveError = rulesStore.lastError }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复。")
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
                entityPicker
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
                entityPicker
                HStack {
                    Text("变为")
                    Spacer()
                    TextField("如 Complete", text: $toString)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(.secondary)
                }
            case .cron:
                cronEditor
            }
        }
    }

    /// Sectioned entity picker — same play as the capability picker:
    /// 5 buckets (空调 / 安全 / 门窗 / 充电 / 电量) so users can scan
    /// to the area they care about instead of reading 10 flat rows.
    private var entityPicker: some View {
        let bucketed: [(VehicleEntity.Category, [VehicleEntity])] = {
            var byCategory: [VehicleEntity.Category: [VehicleEntity]] = [:]
            for entity in VehicleEntity.allCases {
                byCategory[entity.category, default: []].append(entity)
            }
            return VehicleEntity.Category.allCases.compactMap { cat in
                guard let arr = byCategory[cat], !arr.isEmpty else { return nil }
                return (cat, arr)
            }
        }()
        return Menu {
            ForEach(bucketed, id: \.0) { (category, entities) in
                Section(category.label) {
                    ForEach(entities) { e in
                        Button {
                            entity = e
                        } label: {
                            Text(e.label)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("观察项")
                Spacer()
                Text(entity.label)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
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

        // Quick presets — borrowed from iOS 时钟 / 提醒事项.
        VStack(alignment: .leading, spacing: 8) {
            Text("重复").font(.subheadline)
            HStack(spacing: 8) {
                cronPresetChip(label: "每天",   days: Set(1...7))
                cronPresetChip(label: "工作日", days: Set(1...5))
                cronPresetChip(label: "周末",   days: Set([6, 7]))
            }
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
    private func cronPresetChip(label: String, days: Set<Int>) -> some View {
        let active = (cronWeekdays == days)
        Text(label)
            .font(.caption.weight(active ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                active ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill),
                in: Capsule()
            )
            .foregroundStyle(active ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .onTapGesture {
                cronWeekdays = days
            }
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
                capabilityPicker
                if !selectedCapabilityId.isEmpty {
                    capabilityParamRows
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
            // Inline 删除 button when editing an existing user-
            // authored rule. Was a hidden affordance behind the
            // detail page menu before — putting it here means users
            // who reach 编辑 don't have to back out to delete.
            if let r = initial, r.presetId == nil {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Text("删除规则")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("rule_delete_button")
            }
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
        // Either editing an existing rule (`initial`) or duplicating
        // one (`template`). Same hydration shape; only `save()` checks
        // `initial` to decide create vs update.
        guard let r = initial ?? template else { return }
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

    /// Default params for each capability — populated when the user
    /// picks a capability so the rule has sensible defaults.
    /// Capability-specific UI rows below let them tweak.
    private static let defaultParams: [String: [String: JSONValue]] = [
        "tesla.climate.set_keeper_mode":           ["mode": .int(0)],
        "tesla.climate.set_temps":                 ["driver_temp": .double(22), "passenger_temp": .double(22)],
        "tesla.climate.set_preconditioning_max":   ["on": .bool(true)],
        "tesla.climate.set_cabin_overheat":        ["mode": .int(2)],
        "tesla.charging.set_limit":                ["percent": .int(80)],
        "tesla.charging.set_amps":                 ["amps": .int(16)],
        "tesla.security.set_sentry":               ["on": .bool(false)],
        "tesla.comfort.set_seat_heater":           ["seat": .int(0), "level": .int(2)],
        "tesla.comfort.set_steering_wheel_heater": ["on": .bool(true)],
        "tesla.media.set_volume":                  ["volume": .double(5)],
    ]

    /// Sectioned capability picker. Backed by a `Menu` (not `Picker`)
    /// because Picker can't show section dividers inside a Form. The
    /// menu groups the 30+ Tesla capabilities into 7 user-facing
    /// buckets (空调 / 充电 / 安全与门窗 / 座椅与方向盘 / 车机媒体 /
    /// 导航 / 提示与车辆控制) so users can scan to the area they want
    /// instead of reading the whole list.
    private var capabilityPicker: some View {
        let buckets: [(RuleDisplay.CapabilityCategory, [CapabilityInfo])] = {
            var byCategory: [RuleDisplay.CapabilityCategory: [CapabilityInfo]] = [:]
            for cap in capabilitiesStore.capabilities {
                byCategory[RuleDisplay.capabilityCategory(cap.id), default: []].append(cap)
            }
            return RuleDisplay.CapabilityCategory.allCases.compactMap { cat in
                guard let arr = byCategory[cat], !arr.isEmpty else { return nil }
                let sorted = arr.sorted { RuleDisplay.capabilityName($0.id) < RuleDisplay.capabilityName($1.id) }
                return (cat, sorted)
            }
        }()
        let label = selectedCapabilityId.isEmpty
            ? "仅关闭提醒"
            : RuleDisplay.capabilityName(selectedCapabilityId)
        return Menu {
            Button {
                selectedCapabilityId = ""
            } label: {
                Label("仅关闭提醒", systemImage: "checkmark.circle")
            }
            ForEach(buckets, id: \.0) { (category, caps) in
                Section(category.label) {
                    ForEach(caps) { cap in
                        Button {
                            selectedCapabilityId = cap.id
                        } label: {
                            Label(RuleDisplay.capabilityName(cap.id), systemImage: category.symbol)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("点击按钮后执行")
                Spacer()
                Text(label)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .onChange(of: selectedCapabilityId) { _, newId in
            paramOverrides = Self.defaultParams[newId] ?? [:]
        }
    }

    /// Per-capability param-editing UI. Renders a small inline form
    /// keyed off the selected capability id; falls through to a
    /// "无需参数" caption for capabilities that take none.
    @ViewBuilder
    private var capabilityParamRows: some View {
        switch selectedCapabilityId {
        case "tesla.climate.set_keeper_mode":
            Picker("模式", selection: paramIntBinding("mode", default: 0)) {
                Text("关闭").tag(0); Text("保持").tag(1)
                Text("宠物模式").tag(2); Text("露营模式").tag(3)
            }
        case "tesla.security.set_sentry":
            Toggle("开启哨兵", isOn: paramBoolBinding("on", default: false))
        case "tesla.charging.set_limit":
            Stepper(value: paramIntBinding("percent", default: 80), in: 50...100, step: 5) {
                HStack { Text("限额"); Spacer()
                    Text("\(paramIntBinding("percent", default: 80).wrappedValue)%")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
            }
        case "tesla.charging.set_amps":
            Stepper(value: paramIntBinding("amps", default: 16), in: 5...48) {
                HStack { Text("电流"); Spacer()
                    Text("\(paramIntBinding("amps", default: 16).wrappedValue) A")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
            }
        case "tesla.climate.set_temps":
            HStack { Text("主驾"); Spacer()
                Stepper(value: paramDoubleBinding("driver_temp", default: 22), in: 15...28, step: 0.5) {
                    Text("\(paramDoubleBinding("driver_temp", default: 22).wrappedValue, specifier: "%.1f") °C")
                        .foregroundStyle(.secondary)
                }
            }
            HStack { Text("副驾"); Spacer()
                Stepper(value: paramDoubleBinding("passenger_temp", default: 22), in: 15...28, step: 0.5) {
                    Text("\(paramDoubleBinding("passenger_temp", default: 22).wrappedValue, specifier: "%.1f") °C")
                        .foregroundStyle(.secondary)
                }
            }
        case "tesla.climate.set_preconditioning_max":
            Toggle("开启最大预热", isOn: paramBoolBinding("on", default: true))
        case "tesla.climate.set_cabin_overheat":
            Picker("模式", selection: paramIntBinding("mode", default: 2)) {
                Text("关闭").tag(0); Text("空调").tag(1); Text("仅风扇").tag(2)
            }
        case "tesla.comfort.set_seat_heater":
            Picker("座位", selection: paramIntBinding("seat", default: 0)) {
                Text("主驾").tag(0); Text("副驾").tag(1)
                Text("后排左").tag(2); Text("后排中").tag(4); Text("后排右").tag(5)
            }
            Picker("档位", selection: paramIntBinding("level", default: 2)) {
                Text("关闭").tag(0); Text("低").tag(1); Text("中").tag(2); Text("高").tag(3)
            }
        case "tesla.comfort.set_steering_wheel_heater":
            Toggle("开启方向盘加热", isOn: paramBoolBinding("on", default: true))
        case "tesla.media.set_volume":
            HStack { Text("音量"); Spacer()
                Stepper(value: paramDoubleBinding("volume", default: 5), in: 0...11, step: 0.5) {
                    Text("\(paramDoubleBinding("volume", default: 5).wrappedValue, specifier: "%.1f")")
                        .foregroundStyle(.secondary)
                }
            }
        default:
            Text("无需参数")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func paramIntBinding(_ key: String, default def: Int) -> Binding<Int> {
        Binding(
            get: { paramOverrides[key]?.intValue ?? def },
            set: { paramOverrides[key] = .int($0) }
        )
    }

    private func paramBoolBinding(_ key: String, default def: Bool) -> Binding<Bool> {
        Binding(
            get: { paramOverrides[key]?.boolValue ?? def },
            set: { paramOverrides[key] = .bool($0) }
        )
    }

    private func paramDoubleBinding(_ key: String, default def: Double) -> Binding<Double> {
        Binding(
            get: { paramOverrides[key]?.doubleValue ?? def },
            set: { paramOverrides[key] = .double($0) }
        )
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
