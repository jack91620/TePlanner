import SwiftUI
import TePlannerKit

/// Sheet shown when the user taps a row in BatteryView's history.
/// Surfaces every field on the session in a single scrollable layout
/// — start/end time, duration, SOC delta, range added, location,
/// completion status. Read-only; no actions yet.
struct ChargingSessionDetailView: View {
    let session: ChargingSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    timeCard
                    socCard
                    if let range = session.rangeAddedKm, range > 0 {
                        rangeCard(rangeAdded: range)
                    }
                    if session.locationName != nil {
                        locationCard
                    }
                }
                .padding(16)
            }
            .navigationTitle("充电详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .accessibilityIdentifier("session_detail_close")
                }
            }
            .accessibilityIdentifier("session_detail_view")
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(statusColor, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Tokens.spacingMdPlus)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
    }

    private var timeCard: some View {
        infoCard(title: "时间") {
            kvRow("开始", value: formatFullDate(session.startAt))
            if let end = session.endAt {
                kvRow("结束", value: formatFullDate(end))
            } else {
                kvRow("结束", value: "—")
            }
            if let mins = session.durationMinutes {
                kvRow("时长", value: formatMinutes(mins))
            }
        }
    }

    private var socCard: some View {
        infoCard(title: "电量变化") {
            if let start = session.startSoc {
                kvRow("起始 SOC", value: "\(start)%")
            }
            if let end = session.endSoc {
                kvRow("结束 SOC", value: "\(end)%")
            }
            if let delta = session.socDelta {
                kvRow("增加", value: "+\(delta)%", emphasize: true)
            }
        }
    }

    private func rangeCard(rangeAdded: Double) -> some View {
        infoCard(title: "续航变化") {
            if let start = session.startRangeKm {
                kvRow("起始", value: "\(Int(start)) km")
            }
            if let end = session.endRangeKm {
                kvRow("结束", value: "\(Int(end)) km")
            }
            kvRow("新增", value: "+\(Int(rangeAdded)) km", emphasize: true)
        }
    }

    private var locationCard: some View {
        infoCard(title: "地点") {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.tint)
                Text(session.locationName ?? "—")
                    .font(.subheadline)
                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private func infoCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content,
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(Tokens.spacingMdPlus)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surfaceElevated, in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
    }

    private func kvRow(_ key: String, value: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(key).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(emphasize ? .subheadline.weight(.semibold).monospacedDigit() : .subheadline.monospacedDigit())
                .foregroundStyle(emphasize ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
    }

    // 2026-05-11: 「完成 / 中断」二分简化为「充电完成」。`ended_as_complete`
    // 在 closer-handled session 上常被误打成 false（telemetry 已 stale），
    // 反而误导用户。详情页的 SOC delta + 续航增量是更准的「完成度」信号。
    private var statusIcon: String {
        session.isOngoing ? "bolt.circle.fill" : "checkmark.circle.fill"
    }

    private var statusColor: Color {
        session.isOngoing ? .green : .blue
    }

    private var statusTitle: String {
        session.isOngoing ? "进行中" : "充电完成"
    }

    private var statusSubtitle: String {
        if session.isOngoing {
            return "等待结束时再统计电量与续航"
        }
        if let mins = session.durationMinutes {
            return "用时 \(formatMinutes(mins))"
        }
        return "未知时长"
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes == 0 { return "—" }
        if minutes < 60 { return "\(minutes) 分钟" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分"
    }

    private func formatFullDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/M/d HH:mm"
        return f.string(from: date)
    }
}
