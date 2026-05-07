import SwiftUI

/// Phase 5.4 占位页。真正的统计 tab 还没实现 —— 这里先放占位 +
/// 简短说明，避免 hub 上的入口点击进来空白。后续 5.4 落地时只换
/// 这个文件的内容（导航栈 / 入口路径不变）。
struct ChargingStatsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint.opacity(0.6))
            Text("充电统计")
                .font(.title2.weight(.semibold))
            Text("此功能还在路上 —— 计划展示充电次数、平均充电时长、单次能耗、本月费用估算等。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .navigationTitle("充电统计")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("charging_stats_placeholder")
    }
}
