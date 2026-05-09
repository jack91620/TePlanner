import SwiftUI
import TePlannerKit

/// "下次出行" hub card — shows the scheduled departure (date / time
/// / countdown) and a small badge reflecting the most recent preheat
/// dispatch status.
///
/// Pure-render; HubView still owns:
///   - the @State `preheatStatus` (because LocalNotificationScheduler
///     calls `triggerPreheat()` directly when the user taps the
///     '出发前预热' notification's primary action)
///   - the actual API call in `triggerPreheat()`
///
/// This card just shows whatever status HubView passes in and bubbles
/// the tap up via `onTap` so HubView decides whether to open the
/// `ScheduledDepartureSheet`.
struct HubDepartureCard: View {
    let scheduledDeparture: ScheduledDeparture?
    let preheatStatus: PreheatStatus
    let onTap: () -> Void

    enum PreheatStatus: Equatable {
        case idle, sending, sent, failed(String)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "alarm.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    if let scheduled = scheduledDeparture {
                        Text(Self.formatDeparture(scheduled.departureAt))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(Self.subtitle(scheduled))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("下次出行")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("设置出发时间，出发前自动提醒预热")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                preheatBadge
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardButtonStyle())
        .accessibilityIdentifier("hub_departure_card")
    }

    @ViewBuilder
    private var preheatBadge: some View {
        switch preheatStatus {
        case .idle:
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        case .sending:
            ProgressView().controlSize(.small)
        case .sent:
            Label("已启动", systemImage: "checkmark.circle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.green)
        case .failed:
            Label("失败", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
        }
    }

    private static func subtitle(_ departure: ScheduledDeparture) -> String {
        let interval = departure.departureAt.timeIntervalSinceNow
        if interval <= 0 { return "出发时间已到" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "还有 \(minutes) 分钟 · 提前 \(departure.leadTimeMinutes) 分钟提醒" }
        let h = minutes / 60
        let m = minutes % 60
        let countdown = m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分"
        return "还有 \(countdown) · 提前 \(departure.leadTimeMinutes) 分钟提醒"
    }

    private static func formatDeparture(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: date)
    }
}
