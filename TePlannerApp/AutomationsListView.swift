import SwiftUI
import TePlannerKit

/// Settings sub-page that lists every registered Automation rule and
/// lets the user toggle it on/off + adjust its threshold. Mirrors
/// Android's "提醒" intent but each rule's display range is hand-tuned
/// for its own semantics (camp 1–12h, sentry 12–72h, cabin 30min–3h)
/// rather than using one shared slider config.
///
/// Backed directly by `SettingsStore` — saves are immediate so the
/// engine picks up changes on its next tick. Threshold = 0 disables
/// the rule entirely (the rule's `evaluate` short-circuits).
struct AutomationsListView: View {
    @Environment(\.dismiss) private var dismiss
    private let store: SettingsStore
    private let rules: [any Automation]

    @State private var rows: [Row]

    init(rules: [any Automation], store: SettingsStore = UserDefaultsSettingsStore.shared) {
        self.store = store
        self.rules = rules
        let initialRows = rules.map { rule in
            let mins = Self.minutes(for: rule.kind, store: store)
            return Row(
                kind: rule.kind,
                displayName: rule.displayName,
                enabled: mins > 0,
                minutes: max(mins, Self.config(for: rule.kind).range.lowerBound)
            )
        }
        _rows = State(initialValue: initialRows)
    }

    var body: some View {
        Form {
            ForEach(Array(rows.enumerated()), id: \.element.kind) { index, row in
                Section {
                    Toggle(row.displayName, isOn: $rows[index].enabled)
                        .accessibilityIdentifier("automation_toggle_\(row.kind.rawValue)")
                    if rows[index].enabled {
                        let cfg = Self.config(for: row.kind)
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
        }
        .navigationTitle("自动化提醒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { save() }.bold()
                    .accessibilityIdentifier("automations_save_button")
            }
        }
    }

    private func save() {
        for row in rows {
            let mins = row.enabled ? row.minutes : 0
            Self.write(minutes: mins, for: row.kind, store: store)
        }
        Log.app.notice("automations saved")
        dismiss()
    }

    // MARK: - Per-kind config tables

    private struct Row: Equatable {
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

    private static func config(for kind: VehicleAlert.Kind) -> ThresholdConfig {
        switch kind {
        case .campMode:
            return ThresholdConfig(range: 60...720, step: 60, formatter: hoursFormatter)
        case .sentryMode:
            return ThresholdConfig(range: 60...4320, step: 60, formatter: hoursFormatter)
        case .cabinOverheat:
            return ThresholdConfig(range: 30...180, step: 30, formatter: minutesOrHoursFormatter)
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
        }
    }

    private static func minutes(for kind: VehicleAlert.Kind, store: SettingsStore) -> Int {
        switch kind {
        case .campMode: return store.campModeReminderMinutes
        case .sentryMode: return store.sentryReminderMinutes
        case .cabinOverheat: return store.cabinOverheatReminderMinutes
        }
    }

    private static func write(minutes: Int, for kind: VehicleAlert.Kind, store: SettingsStore) {
        switch kind {
        case .campMode: store.campModeReminderMinutes = minutes
        case .sentryMode: store.sentryReminderMinutes = minutes
        case .cabinOverheat: store.cabinOverheatReminderMinutes = minutes
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
