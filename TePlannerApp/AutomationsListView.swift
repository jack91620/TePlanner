import SwiftUI
import TePlannerKit

/// Lists every automation rule on the user's account and lets them
/// flip enabled / tweak the duration threshold. Phase 10.3.B reads
/// from `AutomationRulesStore` (backend-backed) instead of
/// SettingsStore. The visual builder (Phase 10.3.C) is a separate
/// "+" entry that lands later; for now this stays the threshold-
/// slider view.
///
/// Threshold ranges are still hand-tuned per kind (camp 1–12h, sentry
/// 12–72h, cabin 30min–3h). When the visual builder ships, those
/// ranges become inferred from the capability registry.
struct AutomationsListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var rulesStore: AutomationRulesStore

    @State private var rows: [Row] = []
    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
        Form {
            if rows.isEmpty && rulesStore.isLoading {
                ProgressView("加载规则…")
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                Section {
                    Toggle(row.displayName, isOn: $rows[index].enabled)
                        .accessibilityIdentifier("automation_toggle_\(row.kind.rawValue)")
                    if rows[index].enabled, let cfg = Self.config(for: row.kind) {
                        HStack {
                            Text("阈值")
                            Spacer()
                            Text(cfg.formatter(rows[index].minutes))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { Double(rows[index].minutes) },
                                set: { rows[index].minutes = Int($0) }
                            ),
                            in: Double(cfg.range.lowerBound)...Double(cfg.range.upperBound),
                            step: Double(cfg.step)
                        )
                        .accessibilityIdentifier("automation_slider_\(row.kind.rawValue)")
                    }
                } footer: {
                    Text(Self.footer(for: row.kind))
                }
            }
            if let err = saveError {
                Section {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .navigationTitle("自动化提醒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { Task { await save() } }
                    .bold()
                    .disabled(saving || rows.isEmpty)
                    .accessibilityIdentifier("automations_save_button")
            }
        }
        .onAppear { reloadRows() }
        .onChange(of: rulesStore.rules) { _, _ in reloadRows() }
    }

    private func reloadRows() {
        rows = rulesStore.rules.compactMap { record -> Row? in
            guard let kindRaw = record.spec.string("kind"),
                  let kind = VehicleAlert.Kind(rawValue: kindRaw) else {
                return nil
            }
            let mins = currentMinutes(record: record, kind: kind)
            let lowerBound = Self.config(for: kind)?.range.lowerBound ?? 0
            return Row(
                id: record.id,
                kind: kind,
                displayName: record.name,
                enabled: record.enabled,
                minutes: max(mins, lowerBound)
            )
        }
    }

    private func currentMinutes(record: RuleRecord, kind: VehicleAlert.Kind) -> Int {
        if let trigger = record.spec["trigger"]?.objectValue,
           let mins = trigger.int("for_minutes") {
            return mins
        }
        return Self.config(for: kind)?.range.lowerBound ?? 60
    }

    private func save() async {
        saving = true
        saveError = nil
        for row in rows {
            guard let record = rulesStore.rules.first(where: { $0.id == row.id }) else { continue }
            let mutatedSpec = applyThreshold(record.spec, kind: row.kind, minutes: row.minutes)
            let ok = await rulesStore.update(
                id: row.id,
                enabled: row.enabled,
                spec: mutatedSpec
            )
            if !ok {
                saveError = rulesStore.lastError ?? "保存失败"
                saving = false
                return
            }
        }
        saving = false
        Log.app.notice("automations saved (count=\(self.rows.count, privacy: .public))")
        dismiss()
    }

    /// Returns `spec` with the trigger.for_minutes overridden — only
    /// for state_duration triggers, which is all 3 of the threshold-
    /// adjustable presets. ChargeComplete (state_transition) just uses
    /// the toggle.
    private func applyThreshold(_ spec: RuleSpec, kind: VehicleAlert.Kind, minutes: Int) -> RuleSpec {
        var out = spec
        if case .object(var trigger) = out["trigger"] ?? .null,
           trigger.string("type") == "state_duration" {
            trigger["for_minutes"] = .int(minutes)
            out["trigger"] = .object(trigger)
        }
        return out
    }

    // MARK: - Per-kind config tables

    private struct Row: Equatable, Identifiable {
        let id: String
        let kind: VehicleAlert.Kind
        let displayName: String
        var enabled: Bool
        var minutes: Int
    }

    private struct ThresholdConfig {
        let range: ClosedRange<Int>
        let step: Int
        let formatter: (Int) -> String
    }

    /// `nil` ⇒ toggle-only rule (no threshold knob to expose).
    private static func config(for kind: VehicleAlert.Kind) -> ThresholdConfig? {
        switch kind {
        case .campMode:
            return ThresholdConfig(range: 60...720, step: 60, formatter: hoursFormatter)
        case .sentryMode:
            return ThresholdConfig(range: 60...4320, step: 60, formatter: hoursFormatter)
        case .cabinOverheat:
            return ThresholdConfig(range: 30...180, step: 30, formatter: minutesOrHoursFormatter)
        case .chargeComplete:
            return nil
        }
    }

    private static func footer(for kind: VehicleAlert.Kind) -> String {
        switch kind {
        case .campMode:
            return "露营模式开启超过阈值时，App 会显示提醒并允许一键关闭。"
        case .sentryMode:
            return "哨兵模式每小时约消耗 1% 电量。开启时间超过阈值会显示提醒并允许一键关闭。"
        case .cabinOverheat:
            return "座舱过热保护启动后，车辆会自动通风/降温。提醒只是告知正在运行，无操作按钮。"
        case .chargeComplete:
            return "充电进入完成状态时立即提醒，方便你及时拔枪让位给其他车主。"
        }
    }

    private static func hoursFormatter(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分钟"
    }

    private static func minutesOrHoursFormatter(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        return hoursFormatter(minutes)
    }
}
