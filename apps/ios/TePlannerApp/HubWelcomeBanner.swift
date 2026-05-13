import SwiftUI
import TePlannerKit

/// First-launch welcome banner — explains what the app does + 3
/// feature chips, dismissable. Inspired by Shortcuts' first-run
/// "Get Started" card. Pure-render; HubView owns the visibility
/// flag (so it can swap between this and `nil` with animation).
struct HubWelcomeBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                    .font(.title3)
                Text("欢迎使用 Tautomation")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("welcome_banner_dismiss")
            }
            Text("已为你预设 8 条常用自动化提醒——露营超时、忘锁车、充电完成等。在「自动化」中可逐条查看、调整或新增。")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label("Telemetry 实时车况", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label("地理围栏", systemImage: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label("一键执行", systemImage: "hand.tap.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Tokens.spacingMdPlus)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
        .accessibilityIdentifier("hub_welcome_banner")
    }
}
