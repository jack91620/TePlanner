import SwiftUI
import TePlannerKit

/// User-facing preferences page. Backed by `UserDefaultsSettingsStore`
/// (the same singleton the route planner reads). Mirrors Android's
/// settings screen: target arrival SOC, minimum charging SOC,
/// supercharger preference, and the distance unit.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targetArrivalSoc: Int
    @State private var minChargingSoc: Int
    @State private var preferSupercharger: Bool
    @State private var distanceUnit: DistanceUnit
    @State private var campModeReminderHours: Double
    @State private var campModeReminderEnabled: Bool
    private let store: SettingsStore

    init(store: SettingsStore = UserDefaultsSettingsStore.shared) {
        self.store = store
        _targetArrivalSoc = State(initialValue: store.targetArrivalSoc)
        _minChargingSoc = State(initialValue: store.minChargingSoc)
        _preferSupercharger = State(initialValue: store.preferSupercharger)
        _distanceUnit = State(initialValue: store.distanceUnit)
        let mins = store.campModeReminderMinutes
        _campModeReminderEnabled = State(initialValue: mins > 0)
        _campModeReminderHours = State(initialValue: max(1, Double(mins) / 60.0))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("路线规划") {
                    Stepper(value: $targetArrivalSoc, in: 5...50, step: 5) {
                        HStack {
                            Text("目标到达电量")
                            Spacer()
                            Text("\(targetArrivalSoc)%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Stepper(value: $minChargingSoc, in: 5...30, step: 5) {
                        HStack {
                            Text("最低充电电量")
                            Spacer()
                            Text("\(minChargingSoc)%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Toggle("优先选择超级充电站", isOn: $preferSupercharger)
                }
                Section("显示") {
                    Picker("距离单位", selection: $distanceUnit) {
                        Text("公里 (km)").tag(DistanceUnit.kilometers)
                        Text("英里 (mi)").tag(DistanceUnit.miles)
                    }
                }
                Section {
                    Toggle("露营模式超时提醒", isOn: $campModeReminderEnabled)
                    if campModeReminderEnabled {
                        HStack {
                            Text("阈值")
                            Spacer()
                            Text("\(Int(campModeReminderHours)) 小时")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $campModeReminderHours, in: 1...12, step: 1) {
                            Text("阈值")
                        }
                    }
                } header: {
                    Text("提醒")
                } footer: {
                    Text("露营模式开启超过阈值时，App 会显示提醒并允许一键关闭。")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.targetArrivalSoc = targetArrivalSoc
                        store.minChargingSoc = minChargingSoc
                        store.preferSupercharger = preferSupercharger
                        store.distanceUnit = distanceUnit
                        store.campModeReminderMinutes = campModeReminderEnabled
                            ? Int(campModeReminderHours) * 60
                            : 0
                        Log.app.notice("settings saved (target=\(targetArrivalSoc, privacy: .public)% min=\(minChargingSoc, privacy: .public)% super=\(preferSupercharger, privacy: .public) unit=\(distanceUnit.rawValue, privacy: .public) campH=\(campModeReminderEnabled ? Int(campModeReminderHours) : 0, privacy: .public))")
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
