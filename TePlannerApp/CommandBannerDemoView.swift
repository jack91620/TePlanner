import SwiftUI
import TePlannerKit

/// DEBUG-only preview screen that renders the Phase 9/10 command
/// status banner in every state we expect to ship. Reachable via a
/// button on the login screen so we can screenshot the visuals on
/// the simulator without going through Tesla OAuth.
///
/// Compiled out of release builds via the surrounding ``#if DEBUG``
/// — no path to this view exists in the App Store binary.
struct CommandBannerDemoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("待确认（VCP 已发，等车端反馈）") {
                    CommandStatusBanner(
                        pending: PendingCommand(
                            id: 1,
                            capability: "tesla.security.set_sentry",
                            expectedState: ["vehicle.sentry_mode_on": .bool(false)],
                            dispatchedAt: Date().addingTimeInterval(-2),
                            confirmedAt: nil,
                            timedOutAt: nil,
                            status: "pending"
                        ),
                        queued: nil,
                        onCancelQueued: nil,
                    )
                }
                section("已确认（车端确认状态）") {
                    CommandStatusBanner(
                        pending: PendingCommand(
                            id: 2,
                            capability: "tesla.climate.set_keeper_mode",
                            expectedState: ["vehicle.climate.keeper_mode": .int(0)],
                            dispatchedAt: Date().addingTimeInterval(-4),
                            confirmedAt: Date(),
                            timedOutAt: nil,
                            status: "confirmed"
                        ),
                        queued: nil,
                        onCancelQueued: nil,
                    )
                }
                section("超时未确认（60s 内无 telemetry 回应）") {
                    CommandStatusBanner(
                        pending: PendingCommand(
                            id: 3,
                            capability: "tesla.charging.set_limit",
                            expectedState: [:],
                            dispatchedAt: Date().addingTimeInterval(-65),
                            confirmedAt: nil,
                            timedOutAt: Date(),
                            status: "timed_out"
                        ),
                        queued: nil,
                        onCancelQueued: nil,
                    )
                }
                section("已排队（车辆离线，可取消）") {
                    CommandStatusBanner(
                        pending: nil,
                        queued: QueuedCommand(
                            id: 11,
                            capability: "tesla.climate.set_keeper_mode",
                            params: ["mode": .int(0)],
                            dispatchPolicy: "queue",
                            queuedAt: Date().addingTimeInterval(-30),
                            sentAt: nil,
                            droppedAt: nil,
                            ttlSeconds: 1800,
                            error: nil,
                            status: "queued"
                        ),
                        onCancelQueued: { _ in },
                    )
                }
                section("已发送（上线后已自动执行）") {
                    CommandStatusBanner(
                        pending: nil,
                        queued: QueuedCommand(
                            id: 12,
                            capability: "tesla.security.set_sentry",
                            params: ["on": .bool(false)],
                            dispatchPolicy: "queue",
                            queuedAt: Date().addingTimeInterval(-120),
                            sentAt: Date().addingTimeInterval(-2),
                            droppedAt: nil,
                            ttlSeconds: 1800,
                            error: nil,
                            status: "sent"
                        ),
                        onCancelQueued: nil,
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Command Banner 状态演示")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content,
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
