import SwiftUI
import TePlannerKit

/// Phase 5.4 充电统计：本月概览 + 历史会话列表。数据来自客户端检测的
/// `ChargingSessionStore`（HubView 通过 `ChargingSessionTracker`
/// 写入），不依赖任何后端接口——所以离线也能用。等 APNs / 服务端
/// polling 上线后可再引入云同步。
struct ChargingStatsView: View {
    @StateObject private var viewModel: ChargingStatsViewModel

    init(store: ChargingSessionStore = UserDefaultsChargingSessionStore.shared) {
        _viewModel = StateObject(wrappedValue: ChargingStatsViewModel(store: store))
    }

    var body: some View {
        Group {
            if viewModel.hasAnyData {
                content
            } else {
                emptyState
            }
        }
        .navigationTitle("充电统计")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.refresh() }
        .accessibilityIdentifier("charging_stats_view")
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("本月概览")
                    .font(.headline)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(
                        icon: "bolt.fill",
                        title: "充电次数",
                        value: "\(viewModel.monthlyCount) 次"
                    )
                    statCard(
                        icon: "clock.fill",
                        title: "累计时长",
                        value: formatMinutes(viewModel.monthlyDurationMinutes)
                    )
                    statCard(
                        icon: "road.lanes",
                        title: "新增续航",
                        value: "\(Int(viewModel.monthlyRangeAddedKm)) km"
                    )
                    statCard(
                        icon: "battery.100",
                        title: "SOC 增量",
                        value: "\(viewModel.monthlySocDelta)%"
                    )
                }
                .padding(.horizontal, 16)

                Text("历史记录")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                LazyVStack(spacing: 8) {
                    ForEach(viewModel.sessions) { session in
                        sessionRow(session)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint.opacity(0.6))
            Text("暂无充电记录")
                .font(.title3.weight(.semibold))
            Text("从下次充电开始，TePlanner 会自动记录每次会话——前提是 App 在车辆插枪 / 拔枪时处于打开状态。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .accessibilityIdentifier("charging_stats_empty")
    }

    private func statCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(.tint)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func sessionRow(_ s: ChargingSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatDate(s.startAt))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let socStart = s.startSoc, let socEnd = s.endSoc {
                    Text("\(socStart)% → \(socEnd)%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else if s.isOngoing {
                    Label("进行中", systemImage: "circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            HStack(spacing: 8) {
                if let mins = s.durationMinutes {
                    Text(formatMinutes(mins))
                }
                if let km = s.rangeAddedKm, km > 0 {
                    Text("· +\(Int(km)) km")
                }
                if let endedAsComplete = s.endedAsComplete {
                    Text("· \(endedAsComplete ? "完成" : "中断")")
                }
                if let location = s.locationName {
                    Text("· \(location)").lineLimit(1)
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("session_row_\(s.id.uuidString)")
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes == 0 { return "—" }
        if minutes < 60 { return "\(minutes) 分" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}
