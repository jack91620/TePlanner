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
    private let store: SettingsStore
    private let automationRules: [any Automation]

    init(
        store: SettingsStore = UserDefaultsSettingsStore.shared,
        automationRules: [any Automation] = [
            CampModeAutomation(),
            SentryModeAutomation(),
            CabinOverheatAutomation(),
            ChargeCompleteAutomation(),
        ]
    ) {
        self.store = store
        self.automationRules = automationRules
        _targetArrivalSoc = State(initialValue: store.targetArrivalSoc)
        _minChargingSoc = State(initialValue: store.minChargingSoc)
        _preferSupercharger = State(initialValue: store.preferSupercharger)
        _distanceUnit = State(initialValue: store.distanceUnit)
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
                    NavigationLink {
                        AutomationsListView(rules: automationRules, store: store)
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(.tint)
                            Text("自动化提醒")
                            Spacer()
                            Text("\(automationRules.count) 条")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .accessibilityIdentifier("automations_link")
                } header: {
                    Text("提醒")
                } footer: {
                    Text("管理露营 / 哨兵 / 座舱过热等提醒规则。")
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
                        Log.app.notice("settings saved (target=\(targetArrivalSoc, privacy: .public)% min=\(minChargingSoc, privacy: .public)% super=\(preferSupercharger, privacy: .public) unit=\(distanceUnit.rawValue, privacy: .public))")
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
