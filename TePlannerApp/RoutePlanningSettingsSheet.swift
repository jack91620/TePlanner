import SwiftUI
import TePlannerKit

/// 路线规划相关偏好的就地编辑入口。从 MapHomeView（充电规划页）的
/// 菜单进入，包含目标到达 SOC / 最低充电 SOC / 超充偏好 / 距离单位
/// 这些只有在 planning 上下文里才会用到的开关。
///
/// 重构历史：原 SettingsView 是一个全局设置页，里面塞了路线规划 +
/// 显示 + 自动化提醒三块。现在按"在哪里用就在哪里改"原则拆开 ——
/// 自动化阈值已经在 AutomationsListView 里就地可调，这里只剩规划
/// 相关，所以重命名成一个明确的 sheet。
struct RoutePlanningSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targetArrivalSoc: Int
    @State private var minChargingSoc: Int
    @State private var preferSupercharger: Bool
    @State private var distanceUnit: DistanceUnit
    @State private var dailyChargeLimitSoc: Double
    @State private var tripChargeLimitSoc: Double
    private let store: SettingsStore

    init(store: SettingsStore = UserDefaultsSettingsStore.shared) {
        self.store = store
        _targetArrivalSoc = State(initialValue: store.targetArrivalSoc)
        _minChargingSoc = State(initialValue: store.minChargingSoc)
        _preferSupercharger = State(initialValue: store.preferSupercharger)
        _distanceUnit = State(initialValue: store.distanceUnit)
        _dailyChargeLimitSoc = State(initialValue: Double(store.dailyChargeLimitSoc))
        _tripChargeLimitSoc = State(initialValue: Double(store.tripChargeLimitSoc))
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
                Section {
                    HStack {
                        Text("日常")
                        Spacer()
                        Text("\(Int(dailyChargeLimitSoc))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $dailyChargeLimitSoc, in: 50...100, step: 5)
                        .accessibilityIdentifier("daily_charge_limit_slider")
                    HStack {
                        Text("出行前")
                        Spacer()
                        Text("\(Int(tripChargeLimitSoc))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $tripChargeLimitSoc, in: 50...100, step: 5)
                        .accessibilityIdentifier("trip_charge_limit_slider")
                } header: {
                    Text("充电限额预设")
                } footer: {
                    Text("此处设置两档预设值。当车辆当前限额与日常/出行前预设不一致时，主页会出现单独的「建议」卡片让你一键应用。出行前预设在 12 小时内有出行计划时优先生效。")
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
                        store.dailyChargeLimitSoc = Int(dailyChargeLimitSoc)
                        store.tripChargeLimitSoc = Int(tripChargeLimitSoc)
                        Log.app.notice("route-planning settings saved (target=\(targetArrivalSoc, privacy: .public)% min=\(minChargingSoc, privacy: .public)% super=\(preferSupercharger, privacy: .public) unit=\(distanceUnit.rawValue, privacy: .public) dailyLim=\(Int(dailyChargeLimitSoc), privacy: .public)% tripLim=\(Int(tripChargeLimitSoc), privacy: .public)%)")
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
