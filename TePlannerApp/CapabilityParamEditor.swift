import SwiftUI
import TePlannerKit

/// Per-capability inline form rows shown in the rule builder when
/// the user has picked a capability for a `notify_and_offer` action.
/// Extracted from RuleBuilderView so each capability's UI lives in
/// one place and can grow without bloating the builder file.
///
/// The view binds to the rule's `paramOverrides` dict (as
/// Binding<[String: JSONValue]>) — every row mutates a single key
/// inside that dict. When a capability id has no specific UI here
/// we render `无需参数` so the user knows nothing is missing.
struct CapabilityParamEditor: View {
    let capabilityId: String
    @Binding var paramOverrides: [String: JSONValue]

    var body: some View {
        switch capabilityId {
        case "tesla.climate.set_keeper_mode":
            Picker("模式", selection: intBinding("mode", default: 0)) {
                Text("关闭").tag(0); Text("保持").tag(1)
                Text("宠物模式").tag(2); Text("露营模式").tag(3)
            }
        case "tesla.security.set_sentry":
            Toggle("开启哨兵", isOn: boolBinding("on", default: false))
        case "tesla.charging.set_limit":
            Stepper(value: intBinding("percent", default: 80), in: 50...100, step: 5) {
                HStack { Text("限额"); Spacer()
                    Text("\(intBinding("percent", default: 80).wrappedValue)%")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
            }
        case "tesla.charging.set_amps":
            Stepper(value: intBinding("amps", default: 16), in: 5...48) {
                HStack { Text("电流"); Spacer()
                    Text("\(intBinding("amps", default: 16).wrappedValue) A")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
            }
        case "tesla.climate.set_temps":
            HStack { Text("主驾"); Spacer()
                Stepper(value: doubleBinding("driver_temp", default: 22), in: 15...28, step: 0.5) {
                    Text("\(doubleBinding("driver_temp", default: 22).wrappedValue, specifier: "%.1f") °C")
                        .foregroundStyle(.secondary)
                }
            }
            HStack { Text("副驾"); Spacer()
                Stepper(value: doubleBinding("passenger_temp", default: 22), in: 15...28, step: 0.5) {
                    Text("\(doubleBinding("passenger_temp", default: 22).wrappedValue, specifier: "%.1f") °C")
                        .foregroundStyle(.secondary)
                }
            }
        case "tesla.climate.set_preconditioning_max":
            Toggle("开启最大预热", isOn: boolBinding("on", default: true))
        case "tesla.climate.set_cabin_overheat":
            Picker("模式", selection: intBinding("mode", default: 2)) {
                Text("关闭").tag(0); Text("空调").tag(1); Text("仅风扇").tag(2)
            }
        case "tesla.comfort.set_seat_heater":
            Picker("座位", selection: intBinding("seat", default: 0)) {
                Text("主驾").tag(0); Text("副驾").tag(1)
                Text("后排左").tag(2); Text("后排中").tag(4); Text("后排右").tag(5)
            }
            Picker("档位", selection: intBinding("level", default: 2)) {
                Text("关闭").tag(0); Text("低").tag(1); Text("中").tag(2); Text("高").tag(3)
            }
        case "tesla.comfort.set_steering_wheel_heater":
            Toggle("开启方向盘加热", isOn: boolBinding("on", default: true))
        case "tesla.media.set_volume":
            HStack { Text("音量"); Spacer()
                Stepper(value: doubleBinding("volume", default: 5), in: 0...11, step: 0.5) {
                    Text("\(doubleBinding("volume", default: 5).wrappedValue, specifier: "%.1f")")
                        .foregroundStyle(.secondary)
                }
            }
        default:
            Text("无需参数")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func intBinding(_ key: String, default def: Int) -> Binding<Int> {
        Binding(
            get: { paramOverrides[key]?.intValue ?? def },
            set: { paramOverrides[key] = .int($0) }
        )
    }

    private func boolBinding(_ key: String, default def: Bool) -> Binding<Bool> {
        Binding(
            get: { paramOverrides[key]?.boolValue ?? def },
            set: { paramOverrides[key] = .bool($0) }
        )
    }

    private func doubleBinding(_ key: String, default def: Double) -> Binding<Double> {
        Binding(
            get: { paramOverrides[key]?.doubleValue ?? def },
            set: { paramOverrides[key] = .double($0) }
        )
    }
}
