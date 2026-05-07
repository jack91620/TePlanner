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
                    Text("App 会在出发前提醒你启动空调，点击通知后自动调用车辆 HVAC。")
                }

                Section {
                    HStack {
                        Text("提前提醒")
                        Spacer()
                        Text("\(Int(leadTimeMinutes)) 分钟")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $leadTimeMinutes, in: 5...60, step: 5)
                        .accessibilityIdentifier("departure_lead_slider")
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

    /// Nudge the default into "next hour, on the hour" so the picker
    /// opens at a useful starting point instead of the current minute.
    private static func nearestNextHour() -> Date {
        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: now)
        comps.hour = (comps.hour ?? 0) + 1
        comps.minute = 0
        return cal.date(from: comps) ?? now.addingTimeInterval(3600)
    }
}
