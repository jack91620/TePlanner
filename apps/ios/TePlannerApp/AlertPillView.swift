import SwiftUI
import TePlannerKit

/// Top-of-screen overlay that surfaces the highest-priority active
/// `VehicleAlert`. Renders below the status bar, above the map.
/// Tapping the pill calls back to the host with the alert's primary
/// action when one is exposed (e.g. "关闭露营模式").
struct AlertPillView: View {
    let alert: VehicleAlert
    let onPrimaryAction: (() -> Void)?
    @State private var isFiring = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(severityColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(alert.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if let label = alert.primaryActionLabel, let action = onPrimaryAction {
                Button {
                    isFiring = true
                    action()
                    // Re-enable in case the alert lingers (action
                    // failed) so user can retry. Engine drops the
                    // alert on success → pill goes away → state is
                    // discarded with the view.
                    Task {
                        try? await Task.sleep(nanoseconds: 6 * 1_000_000_000)
                        await MainActor.run { isFiring = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isFiring {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.mini)
                                .tint(.white)
                        }
                        Text(isFiring ? "执行中" : label)
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(severityColor, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isFiring)
                .accessibilityIdentifier("alert_primary_action_\(alert.kind.rawValue)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(severityColor.opacity(0.4), lineWidth: 1)
        )
        .contextMenu {
            Button {
                let text = "【\(alert.title)】\n\(alert.detail)"
                UIPasteboard.general.string = text
            } label: {
                Label("复制提醒内容", systemImage: "doc.on.doc")
            }
        }
        .accessibilityIdentifier("alert_pill_\(alert.kind.rawValue)")
    }

    private var iconName: String {
        switch alert.kind {
        case .campMode: return "moon.zzz.fill"
        case .sentryMode: return "shield.lefthalf.filled"
        case .cabinOverheat: return "thermometer.sun.fill"
        case .chargeComplete: return "bolt.fill"
        case .leftUnlocked: return "lock.open.fill"
        case .closureLeftOpen: return "door.left.hand.open"
        case .lowBattery: return "battery.25"
        case .weekdayPreheat: return "alarm.fill"
        case .geofenceEnter: return "location.fill"
        case .geofenceExit: return "location.slash.fill"
        case .connectivity: return "antenna.radiowaves.left.and.right"
        }
    }

    private var severityColor: Color {
        switch alert.severity {
        case .info: return .blue
        case .critical: return .orange
        }
    }
}
