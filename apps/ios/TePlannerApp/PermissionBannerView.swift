import SwiftUI
import UserNotifications
import TePlannerKit

/// Surfaced on Hub when the user denied notification permission.
/// Without notifications the camp / sentry / cabin / charge alerts
/// never reach the user — the whole product loses its loop. We
/// nag once per day; users who keep dismissing the banner stop
/// seeing it until tomorrow.
///
/// Don't surface for `.notDetermined` (the system prompt will fire
/// on first request) or `.authorized` / `.provisional` (already on).
struct PermissionBannerView: View {
    let status: UNAuthorizationStatus
    @Binding var hideUntil: Date?

    private static let nagInterval: TimeInterval = 24 * 60 * 60
    @Environment(\.openURL) private var openURL

    var shouldShow: Bool {
        guard status == .denied else { return false }
        if let hideUntil, Date() < hideUntil { return false }
        return true
    }

    var body: some View {
        if shouldShow {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.orange, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("通知权限未开启")
                        .font(.subheadline.weight(.semibold))
                    Text("没有通知就收不到露营 / 哨兵 / 充电完成等提醒。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button("去开启") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("permission_open_settings")

                        Button("今天先不") {
                            hideUntil = Date().addingTimeInterval(Self.nagInterval)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("permission_dismiss_today")
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Tokens.colorWashPermission.opacity(Tokens.colorWashPermissionAlpha), in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
            .accessibilityIdentifier("permission_banner")
        }
    }
}
