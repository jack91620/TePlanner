import SwiftUI
import TePlannerKit

/// Hub "进行中行程" card. Surfaces:
///   - current / next stop name + 剩余 N 段
///   - "下一段" button (manual advance until phase 2's cron monitor)
///   - replan-reason banner when the last replan attached one
///   - tap-and-hold / contextual cancel
///
/// Mirrors the visual treatment of HubDepartureCard so adjacent
/// cards feel consistent.
struct HubActiveTripCard: View {
    let trip: ActiveTrip
    let nextStop: TripStop
    let isLoading: Bool
    let onAdvance: () -> Void
    let onCancel: () -> Void

    @State private var showCancelConfirm: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            stopRow
            if let reason = trip.lastReplanReason, !reason.isEmpty {
                replanBanner(reason: reason)
            }
            actionRow
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
        .accessibilityIdentifier("hub_active_trip_card")
        .contextMenu {
            Button("取消行程", role: .destructive) {
                showCancelConfirm = true
            }
        }
        .confirmationDialog(
            "取消正在进行的行程？",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible,
        ) {
            Button("取消行程", role: .destructive) { onCancel() }
            Button("继续", role: .cancel) {}
        } message: {
            Text("Tesla 车机里的导航不会被自动清除，需要在车机上手动取消。")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text("进行中行程")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(progressLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var stopRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: stopIcon)
                .font(.title3)
                .foregroundStyle(stopTint)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(stopTitle)
                    .font(.body.weight(.medium))
                    .accessibilityIdentifier("hub_active_trip_next_stop")
                if let secondary = stopSecondary {
                    Text(secondary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private func replanBanner(reason: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption.weight(.semibold))
            Text("路线已重新规划：\(reason)")
                .font(.caption2)
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.orange)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                onAdvance()
            } label: {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.mini)
                    }
                    Text(advanceLabel)
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(isLoading || trip.isOnFinalStop && trip.currentSegment >= 0)
            .accessibilityIdentifier("hub_active_trip_advance")
        }
    }

    // MARK: - Derived

    private var progressLabel: String {
        let total = trip.stops.count
        // current_segment is 0-based; show 1-based with "/ total".
        // -1 means stop 0 not yet sent (e.g. car offline at start).
        let cur = max(trip.currentSegment + 1, 1)
        return "\(cur) / \(total)"
    }

    private var stopIcon: String {
        switch nextStop.kind {
        case .charging: return "bolt.car.circle.fill"
        case .final:    return "flag.checkered.circle.fill"
        }
    }

    private var stopTint: Color {
        nextStop.kind == .final ? .green : .blue
    }

    private var stopTitle: String {
        nextStop.name ?? nextStop.address ?? (
            nextStop.kind == .final ? "目的地" : "充电站"
        )
    }

    private var stopSecondary: String? {
        // Show address as subtitle if we used name as title — avoid
        // repeating the same string.
        if nextStop.name != nil, let addr = nextStop.address, !addr.isEmpty {
            return addr
        }
        if let target = nextStop.socTarget {
            return "目标到站电量 \(target)%"
        }
        return nil
    }

    private var advanceLabel: String {
        if trip.currentSegment < 0 {
            return "发送第一站到车"
        }
        if trip.isOnFinalStop {
            return "已发送到终点"
        }
        return "下一段已到达，发送下一站"
    }
}
