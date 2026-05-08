import SwiftUI
import TePlannerKit

/// Phase 9 + 10 UI: surfaces the result of recently-issued VCP
/// commands as a slim banner under the alert pill. Shows two flavors:
///
/// - **Pending (in-flight)** — "正在关闭哨兵…" / "已关闭" / "超时"
///   driven by `/api/v1/vehicles/commands/pending`. Auto-dismisses
///   ~3 s after a confirmed/timed_out resolution lands.
///
/// - **Queued (offline)** — "已排队 — 上线后自动执行" with a cancel
///   button, driven by `/api/v1/vehicles/commands/queued`. Sticks
///   around until the row is sent/dropped/cancelled.
///
/// Both fetch happens on a 5-second cadence while the banner is
/// active; on first observation of a new pending row we kick a
/// quick-poll mode (1 s) for ~10 s to catch the confirmation fast.
struct CommandStatusBanner: View {
    let pending: PendingCommand?
    let queued: QueuedCommand?
    let onCancelQueued: ((Int) -> Void)?

    var body: some View {
        if let pending {
            pendingRow(pending)
        } else if let queued {
            queuedRow(queued)
        }
    }

    @ViewBuilder
    private func pendingRow(_ p: PendingCommand) -> some View {
        HStack(spacing: 12) {
            Group {
                if p.status == "pending" {
                    if #available(iOS 18.0, *) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolEffect(.rotate, options: .repeating)
                    } else {
                        SpinningRefreshIcon()
                    }
                } else {
                    Image(systemName: pendingIcon(p.status))
                }
            }
            .font(.title3)
            .foregroundStyle(pendingColor(p.status))
            VStack(alignment: .leading, spacing: 2) {
                Text(pendingTitle(p))
                    .font(.subheadline.weight(.semibold))
                Text(pendingDetail(p))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(pendingColor(p.status).opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("command_pending_banner_\(p.status)")
    }

    @ViewBuilder
    private func queuedRow(_ q: QueuedCommand) -> some View {
        HStack(spacing: 12) {
            Image(systemName: queuedIcon(q.status))
                .font(.title3)
                .foregroundStyle(queuedColor(q.status))
            VStack(alignment: .leading, spacing: 2) {
                Text(queuedTitle(q))
                    .font(.subheadline.weight(.semibold))
                Text(queuedDetail(q))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if q.status == "queued", let onCancel = onCancelQueued {
                Button("取消") { onCancel(q.id) }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(.secondary)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("command_queued_cancel_\(q.id)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(queuedColor(q.status).opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("command_queued_banner_\(q.status)_\(q.id)")
    }

    private func queuedIcon(_ status: String) -> String {
        switch status {
        case "sent":    return "checkmark.circle.fill"
        case "dropped": return "xmark.circle.fill"
        default:        return "tray.full.fill"
        }
    }

    private func queuedColor(_ status: String) -> Color {
        switch status {
        case "sent":    return .green
        case "dropped": return .gray
        default:        return .orange
        }
    }

    private struct SpinningRefreshIcon: View {
        @State private var rotation: Double = 0
        var body: some View {
            Image(systemName: "arrow.triangle.2.circlepath")
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        }
    }

    private func queuedDetail(_ q: QueuedCommand) -> String {
        switch q.status {
        case "sent":
            return "车辆已上线，命令已发送"
        case "dropped":
            return q.error?.contains("cancelled") == true
                ? "已取消" : "已超时未执行"
        default:
            return "车辆离线，下次上线时自动执行"
        }
    }

    // MARK: - text formatting

    private func pendingTitle(_ p: PendingCommand) -> String {
        let action = capabilityVerbWithTarget(p.capability, expected: p.expectedState)
        switch p.status {
        case "confirmed": return "已\(action)"
        case "timed_out": return "\(action) — 未确认"
        default:          return "正在\(action)…"
        }
    }

    private func pendingDetail(_ p: PendingCommand) -> String {
        switch p.status {
        case "confirmed":
            return "车辆已确认，操作完成"
        case "timed_out":
            return "60 秒内未收到车辆反馈，请稍后重试"
        default:
            return "等待车辆确认"
        }
    }

    /// "切换哨兵" → "关闭哨兵" / "开启哨兵" depending on expected
    /// payload. Falls back to the verb-only form when we can't infer.
    private func capabilityVerbWithTarget(
        _ id: String, expected: [String: JSONValue],
    ) -> String {
        switch id {
        case "tesla.security.set_sentry":
            if case .bool(let on) = expected["vehicle.sentry_mode_on"] {
                return on ? "开启哨兵" : "关闭哨兵"
            }
            return "切换哨兵"
        case "tesla.climate.set_keeper_mode":
            if case .int(let mode) = expected["vehicle.climate.keeper_mode"] {
                switch mode {
                case 0: return "关闭空调保持"
                case 1: return "开启空调保持"
                case 2: return "开启宠物模式"
                case 3: return "开启露营模式"
                default: return "切换空调保持"
                }
            }
            return "切换空调保持"
        default:
            return capabilityHumanName(id)
        }
    }

    private func pendingIcon(_ status: String) -> String {
        switch status {
        case "confirmed": return "checkmark.circle.fill"
        case "timed_out": return "exclamationmark.triangle.fill"
        default:          return "arrow.triangle.2.circlepath"
        }
    }

    private func pendingColor(_ status: String) -> Color {
        switch status {
        case "confirmed": return .green
        case "timed_out": return .orange
        default:          return .blue
        }
    }

    private func queuedTitle(_ q: QueuedCommand) -> String {
        // For queued items we have the params at hand (not the
        // expected_state), so map params → target verb directly.
        let action: String
        switch q.capability {
        case "tesla.security.set_sentry":
            if case .bool(let on) = q.params["on"] {
                action = on ? "开启哨兵" : "关闭哨兵"
            } else { action = "切换哨兵" }
        case "tesla.climate.set_keeper_mode":
            if case .int(let mode) = q.params["mode"] {
                switch mode {
                case 0: action = "关闭空调保持"
                case 1: action = "开启空调保持"
                case 2: action = "开启宠物模式"
                case 3: action = "开启露营模式"
                default: action = "切换空调保持"
                }
            } else { action = "切换空调保持" }
        default:
            action = capabilityHumanName(q.capability)
        }
        switch q.status {
        case "sent":    return "已\(action)"
        case "dropped": return action
        default:        return "已排队：\(action)"
        }
    }

    /// Map capability id to the user-facing verb. Same vocabulary as
    /// alert pills so users see consistent terminology between trigger
    /// alerts and their command outcomes.
    private func capabilityHumanName(_ id: String) -> String {
        switch id {
        case "tesla.climate.set_keeper_mode": return "切换空调保持"
        case "tesla.climate.preheat":          return "启动预热"
        case "tesla.security.set_sentry":      return "切换哨兵"
        case "tesla.charging.set_limit":       return "调整充电限额"
        case "tesla.navigation.send":          return "发送导航"
        default:                                return "执行命令"
        }
    }
}
