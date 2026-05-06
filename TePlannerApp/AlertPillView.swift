import SwiftUI
import TePlannerKit

/// Top-of-screen overlay that surfaces the highest-priority active
/// `VehicleAlert`. Renders below the status bar, above the map.
/// Tapping the pill calls back to the host with the alert's primary
/// action when one is exposed (e.g. "关闭露营模式").
struct AlertPillView: View {
    let alert: VehicleAlert
    let onPrimaryAction: (() -> Void)?

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
                Button(action: action) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(severityColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
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
        .accessibilityIdentifier("alert_pill_\(alert.kind.rawValue)")
    }

    private var iconName: String {
        switch alert.kind {
        case .campMode: return "moon.zzz.fill"
        }
    }

    private var severityColor: Color {
        switch alert.severity {
        case .info: return .blue
        case .critical: return .orange
        }
    }
}
