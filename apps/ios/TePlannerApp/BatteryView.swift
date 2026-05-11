import SwiftUI
import TePlannerKit

/// 电池管理页：聚合一切跟车辆电池有关的视图与控制——
///
/// - 当前限额 + 立即调整 slider + 应用到车辆按钮（手动一次性场景）
/// - 限额预设（日常 / 出行前）—— Hub 的"建议"卡片读这两档来比对
/// - 本月充电概览（次数 / 时长 / 续航增量 / SOC 增量）
/// - 历史会话列表（来自客户端 ChargingSessionTracker）
///
/// 设计动机：原本"立即调整充电限额"放在路线规划设置里，但充电限额
/// 与路线规划领域正交（电池行为 vs. 单次出行规划）。把电池相关的
/// 全部集中到一个 top-level 入口，未来加电池健康 / 充电曲线等就
/// 直接往里面加 section，导航不再纠缠。
struct BatteryView: View {
    @StateObject private var statsVM: ChargingStatsViewModel
    @State private var dailyChargeLimitSoc: Double
    @State private var tripChargeLimitSoc: Double
    @State private var manualChargeLimit: Double
    @State private var manualApplyStatus: ManualApplyStatus = .idle
    private let store: SettingsStore
    private let apiService: APIServiceProtocol?
    private let vehicleId: String?
    private let currentChargeLimitSoc: Int?
    private let onLimitApplied: (() -> Void)?

    init(
        sessionStore: ChargingSessionStore,
        store: SettingsStore = UserDefaultsSettingsStore.shared,
        apiService: APIServiceProtocol? = nil,
        vehicleId: String? = nil,
        currentChargeLimitSoc: Int? = nil,
        onLimitApplied: (() -> Void)? = nil
    ) {
        _statsVM = StateObject(wrappedValue: ChargingStatsViewModel(store: sessionStore))
        self.store = store
        self.apiService = apiService
        self.vehicleId = vehicleId
        self.currentChargeLimitSoc = currentChargeLimitSoc
        self.onLimitApplied = onLimitApplied
        _dailyChargeLimitSoc = State(initialValue: Double(store.dailyChargeLimitSoc))
        _tripChargeLimitSoc = State(initialValue: Double(store.tripChargeLimitSoc))
        _manualChargeLimit = State(initialValue: Double(currentChargeLimitSoc ?? 80))
    }

    enum ManualApplyStatus: Equatable {
        case idle, sending, sent(Int), failed(String)
    }

    @State private var detailSession: ChargingSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if apiService != nil, vehicleId != nil {
                    chargeLimitCard
                }
                presetsCard
                if statsVM.hasAnyData {
                    monthlyOverview
                    historySection
                } else {
                    statsEmptyHint
                }
            }
            .padding(16)
        }
        .navigationTitle("电池管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await statsVM.refresh(vehicleId: vehicleId) }
        .accessibilityIdentifier("battery_view")
        .sheet(item: $detailSession) { session in
            ChargingSessionDetailView(session: session)
        }
    }

    // MARK: - 充电限额（手动）

    @ViewBuilder
    private var chargeLimitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("充电限额")
                .font(.headline)

            if let current = currentChargeLimitSoc {
                HStack {
                    Text("车辆当前").foregroundStyle(.secondary).font(.subheadline)
                    Spacer()
                    Text("\(current)%")
                        .font(.headline.monospacedDigit())
                }
            }
            HStack {
                Text("目标").foregroundStyle(.secondary).font(.subheadline)
                Spacer()
                Text("\(Int(manualChargeLimit))%")
                    .font(.title3.monospacedDigit())
            }
            Slider(value: $manualChargeLimit, in: 50...100, step: 5)
                .accessibilityIdentifier("manual_charge_limit_slider")
            Button {
                applyManualChargeLimit()
            } label: {
                HStack {
                    Spacer()
                    manualApplyLabel
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(
                manualApplyStatus == .sending ||
                apiService == nil ||
                vehicleId == nil ||
                Int(manualChargeLimit) == currentChargeLimitSoc
            )
            .accessibilityIdentifier("apply_manual_charge_limit_button")
            if Int(manualChargeLimit) == currentChargeLimitSoc {
                Text("当前限额已是 \(Int(manualChargeLimit))%，无需重复发送")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("跳过预设直接发命令到车辆。出长途调到 100% 等一次性场景用此入口。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var manualApplyLabel: some View {
        switch manualApplyStatus {
        case .idle:
            Label("应用到车辆", systemImage: "paperplane.fill")
        case .sending:
            ProgressView()
        case .sent(let percent):
            Label("已发送 \(percent)%", systemImage: "checkmark.circle.fill")
        case .failed:
            Label("失败 · 重试", systemImage: "exclamationmark.triangle")
        }
    }

    private func applyManualChargeLimit() {
        guard let api = apiService, let vid = vehicleId else { return }
        let percent = Int(manualChargeLimit)
        manualApplyStatus = .sending
        Log.vehicle.notice("battery: manual charge-limit apply: \(percent, privacy: .public)%")
        Task {
            let result = await api.setChargeLimit(vehicleId: vid, percent: percent)
            switch result {
            case .success:
                manualApplyStatus = .sent(percent)
                onLimitApplied?()
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                if case .sent = manualApplyStatus { manualApplyStatus = .idle }
            case .failure(let err):
                manualApplyStatus = .failed(err.localizedDescription)
                Log.vehicle.error("battery: manual charge-limit failed: \(err.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - 限额预设

    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("限额预设").font(.headline)
            HStack {
                Text("日常")
                Spacer()
                Text("\(Int(dailyChargeLimitSoc))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $dailyChargeLimitSoc, in: 50...100, step: 5,
                   onEditingChanged: { editing in
                       if !editing { store.dailyChargeLimitSoc = Int(dailyChargeLimitSoc) }
                   })
                .accessibilityIdentifier("daily_charge_limit_slider")
            HStack {
                Text("出行前")
                Spacer()
                Text("\(Int(tripChargeLimitSoc))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $tripChargeLimitSoc, in: 50...100, step: 5,
                   onEditingChanged: { editing in
                       if !editing { store.tripChargeLimitSoc = Int(tripChargeLimitSoc) }
                   })
                .accessibilityIdentifier("trip_charge_limit_slider")
            Text("当车辆当前限额与日常 / 出行前预设不一致时，主页会出现「建议」卡片让你一键应用。出行前预设在 12 小时内有出行计划时优先生效。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - 充电统计

    private var monthlyOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本月概览").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCard(icon: "bolt.fill", title: "充电次数", value: "\(statsVM.monthlyCount) 次")
                statCard(icon: "clock.fill", title: "累计时长", value: formatMinutes(statsVM.monthlyDurationMinutes))
                statCard(icon: "road.lanes", title: "新增续航", value: "\(Int(statsVM.monthlyRangeAddedKm)) km")
                statCard(icon: "battery.100", title: "SOC 增量", value: "\(statsVM.monthlySocDelta)%")
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("历史记录").font(.headline)
            LazyVStack(spacing: 8) {
                ForEach(statsVM.sessions) { session in
                    Button { detailSession = session } label: {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("session_row_\(session.id.uuidString)")
                }
            }
        }
    }

    private var statsEmptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint.opacity(0.6))
            Text("暂无充电记录").font(.subheadline.weight(.semibold))
            Text("从下次充电开始，App 会自动记录每次会话——前提是 App 在车辆插枪 / 拔枪时处于打开状态。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(.tint)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(value).font(.title3.weight(.semibold).monospacedDigit())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
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
                if let mins = s.durationMinutes { Text(formatMinutes(mins)) }
                if let km = s.rangeAddedKm, km > 0 { Text("· +\(Int(km)) km") }
                if let endedAsComplete = s.endedAsComplete {
                    Text("· \(endedAsComplete ? "完成" : "中断")")
                }
                if let location = s.locationName { Text("· \(location)").lineLimit(1) }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes == 0 { return "—" }
        if minutes < 60 { return "\(minutes) 分" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分"
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:mm"
        return f.string(from: date)
    }
}
