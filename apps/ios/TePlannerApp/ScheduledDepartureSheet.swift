import SwiftUI
import TePlannerKit

/// Modal for setting / editing the next-departure schedule. DatePicker
/// for the departure time + slider for the lead minutes (5–60).
/// Saved value triggers the host to (re)schedule the local
/// notification.
struct ScheduledDepartureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var departureAt: Date
    @State private var leadTimeMinutes: Double
    @State private var label: String
    private let vehicleId: String?
    private let onSave: (ScheduledDeparture) -> Void
    private let onClear: (() -> Void)?

    init(
        existing: ScheduledDeparture? = nil,
        vehicleId: String?,
        onSave: @escaping (ScheduledDeparture) -> Void,
        onClear: (() -> Void)? = nil
    ) {
        let nextHour = Self.nearestNextHour()
        _departureAt = State(initialValue: existing?.departureAt ?? nextHour)
        _leadTimeMinutes = State(initialValue: Double(existing?.leadTimeMinutes ?? 15))
        _label = State(initialValue: existing?.label ?? "")
        self.vehicleId = vehicleId
        self.onSave = onSave
        self.onClear = onClear
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "出发时间",
                        selection: $departureAt,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier("departure_picker")
                    TextField("备注（选填）", text: $label)
                        .accessibilityIdentifier("departure_label_field")
                } header: {
                    Text("下次出行")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("App 会在出发前提醒你启动空调，点击通知后自动调用车辆 HVAC。")
                        Text("提示：Tesla 车机也有「预定出行」功能，如果在车机上已配置类似计划，建议只保留一处，避免双重预热。")
                            .foregroundStyle(.orange)
                    }
                    .accessibilityIdentifier("departure_conflict_hint")
                }

                Section {
                    HStack {
                        Text("提前提醒")
                        Spacer()
                        Text("\(Int(leadTimeMinutes)) 分钟")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $leadTimeMinutes, in: 5...60, step: 5) {
                        Text("提前提醒")
                    } minimumValueLabel: {
                        Text("5")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("60")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("departure_lead_slider")
                } footer: {
                    Text("空调预热通常需要 10–20 分钟达到舒适温度，冬季可调高。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if onClear != nil {
                    Section {
                        Button("取消下次出行", role: .destructive) {
                            onClear?()
                            dismiss()
                        }
                        .accessibilityIdentifier("departure_clear_button")
                    }
                }
            }
            .navigationTitle("出行计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let entry = ScheduledDeparture(
                            label: label.isEmpty ? nil : label,
                            departureAt: departureAt,
                            leadTimeMinutes: Int(leadTimeMinutes),
                            vehicleId: vehicleId
                        )
                        onSave(entry)
                        dismiss()
                    }
                    .bold()
                    .accessibilityIdentifier("departure_save_button")
                }
            }
        }
    }

    /// Pick a useful default departure time. People who set "next
    /// departure" in the morning tend to mean "today's commute" or
    /// "this evening"; people who set it after work tend to mean
    /// "tomorrow morning". Anchor on the typical 8am / 6pm slots.
    private static func nearestNextHour() -> Date {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.minute = 0
        comps.second = 0
        switch hour {
        case 0..<6:    // late night → today 8am
            comps.hour = 8
        case 6..<12:   // morning → today 6pm (after-work return / evening)
            comps.hour = 18
        case 12..<22:  // afternoon / evening → tomorrow 8am
            if let tomorrow = cal.date(byAdding: .day, value: 1, to: now) {
                comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
                comps.minute = 0; comps.second = 0
                comps.hour = 8
            }
        default:       // late night again → tomorrow 8am
            if let tomorrow = cal.date(byAdding: .day, value: 1, to: now) {
                comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
                comps.minute = 0; comps.second = 0
                comps.hour = 8
            }
        }
        return cal.date(from: comps) ?? now.addingTimeInterval(3600)
    }
}
