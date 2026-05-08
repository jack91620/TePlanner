import SwiftUI
import TePlannerKit

/// 活动 — chronological timeline of every rule-fire push the
/// backend has shipped for this user. Helps users answer "did my
/// camp-mode rule fire while I wasn't looking?" without scrubbing
/// notification center.
///
/// Reachable from the hub menu / settings.
struct RecentFiresView: View {
    let apiService: APIServiceProtocol
    @State private var fires: [RecentFireEntry] = []
    @State private var loading = false
    @State private var lastError: String?

    var body: some View {
        List {
            if loading && fires.isEmpty {
                Section { ProgressView("加载触发记录…") }
            } else if fires.isEmpty {
                emptyState
            } else {
                ForEach(grouped, id: \.0) { day, entries in
                    Section(header: Text(day)) {
                        ForEach(entries) { fire in
                            row(fire)
                        }
                    }
                }
            }
            if let err = lastError {
                Section {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .navigationTitle("活动")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    @ViewBuilder
    private var emptyState: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.tint.opacity(0.6))
                Text("还没有触发记录")
                    .font(.headline)
                Text("当某条自动化规则首次推送通知，就会出现在这里。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }

    private func row(_ fire: RecentFireEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kindIcon(fire.kind))
                .foregroundStyle(kindAccent(fire.kind))
                .font(.title3)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(kindName(fire.kind))
                    .font(.subheadline.weight(.medium))
                Text(timeText(fire.pushedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if fire.clearedAt != nil {
                    Text("已清除")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
            Spacer()
        }
    }

    private func load() async {
        if !loading { loading = true }
        defer { loading = false }
        switch await apiService.fetchRecentFires(limit: 50) {
        case .success(let resp):
            fires = resp.fires
            lastError = nil
        case .failure(let err):
            lastError = err.localizedDescription
        }
    }

    /// Group fires by day for the "今天 / 昨天 / X 月 X 日" headers
    /// the way 通知中心 / 信息 group messages.
    private var grouped: [(String, [RecentFireEntry])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"

        var groups: [(String, [RecentFireEntry])] = []
        var current: (String, [RecentFireEntry])? = nil
        for fire in fires {
            let day = cal.startOfDay(for: fire.pushedAt)
            let label: String
            if day == today { label = "今天" }
            else if day == yesterday { label = "昨天" }
            else { label = formatter.string(from: fire.pushedAt) }
            if current?.0 == label {
                current?.1.append(fire)
            } else {
                if let c = current { groups.append(c) }
                current = (label, [fire])
            }
        }
        if let c = current { groups.append(c) }
        return groups
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func kindName(_ raw: String) -> String {
        switch raw {
        case "campMode":          return "露营模式超时"
        case "sentryMode":        return "哨兵模式长时间开启"
        case "cabinOverheat":     return "座舱过热保护"
        case "chargeComplete":    return "充电完成"
        case "leftUnlocked":      return "停车后忘锁车"
        case "closureLeftOpen":   return "车窗 / 后备箱忘关"
        case "lowBattery":        return "电量过低"
        case "weekdayPreheat":    return "工作日预热"
        case "geofenceEnter":     return "进入地理围栏"
        case "geofenceExit":      return "离开地理围栏"
        case "connectivity":      return "连接状态变化"
        default:                  return raw
        }
    }

    private func kindIcon(_ raw: String) -> String {
        switch raw {
        case "campMode":         return "moon.zzz.fill"
        case "sentryMode":       return "shield.lefthalf.filled"
        case "cabinOverheat":    return "thermometer.sun.fill"
        case "chargeComplete":   return "bolt.batteryblock.fill"
        case "leftUnlocked":     return "lock.open.fill"
        case "closureLeftOpen":  return "door.left.hand.open"
        case "lowBattery":       return "battery.25"
        case "weekdayPreheat":   return "alarm.fill"
        case "geofenceEnter":    return "location.fill"
        case "geofenceExit":     return "location.slash.fill"
        case "connectivity":     return "antenna.radiowaves.left.and.right"
        default:                 return "bell.badge.fill"
        }
    }

    private func kindAccent(_ raw: String) -> Color {
        switch raw {
        case "lowBattery", "leftUnlocked", "closureLeftOpen": return .orange
        case "campMode", "sentryMode":                        return .purple
        case "cabinOverheat":                                 return .red
        case "weekdayPreheat":                                return .blue
        case "geofenceEnter", "geofenceExit":                 return .green
        case "connectivity":                                  return .indigo
        default:                                              return .accentColor
        }
    }
}
