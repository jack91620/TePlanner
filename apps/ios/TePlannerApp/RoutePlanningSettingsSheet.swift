import SwiftUI
import TePlannerKit

/// 路线规划相关偏好的就地编辑入口。从 MapHomeView（充电规划页）的
/// 菜单进入，包含目标到达 SOC / 最低充电 SOC / 超充偏好 / 距离单位
/// 这些只有在 planning 上下文里才会用到的开关。
///
/// 充电限额（预设 + 立即调整）以及充电统计已迁移到 Hub 的「电池管理」
/// 入口（BatteryView）—— 它们属于车辆电池管理域，与"规划本次出行"
/// 这个动作正交。
struct RoutePlanningSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targetArrivalSoc: Int
    @State private var minChargingSoc: Int
    @State private var preferSupercharger: Bool
    @State private var distanceUnit: DistanceUnit
    private let store: SettingsStore

    init(store: SettingsStore = UserDefaultsSettingsStore.shared) {
        self.store = store
        _targetArrivalSoc = State(initialValue: store.targetArrivalSoc)
        _minChargingSoc = State(initialValue: store.minChargingSoc)
        _preferSupercharger = State(initialValue: store.preferSupercharger)
        _distanceUnit = State(initialValue: store.distanceUnit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("电量目标") {
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
                }
                Section("充电站偏好") {
                    Toggle("优先选择超级充电站", isOn: $preferSupercharger)
                }
                Section("显示") {
                    Picker("距离单位", selection: $distanceUnit) {
                        Text("公里 (km)").tag(DistanceUnit.kilometers)
                        Text("英里 (mi)").tag(DistanceUnit.miles)
                    }
                }
            }
            .navigationTitle("路线规划设置")
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
                        Log.app.notice("route-planning settings saved (target=\(targetArrivalSoc, privacy: .public)% min=\(minChargingSoc, privacy: .public)% super=\(preferSupercharger, privacy: .public) unit=\(distanceUnit.rawValue, privacy: .public))")
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
