import SwiftUI
import TePlannerKit

/// "最近" tab content. Shows the user's saved route plans
/// (GET /routes/). Tapping a row could re-open the preview later;
/// for now it just exposes a callback for the host to wire.
struct RecentTripsView: View {
    @StateObject private var viewModel: RecentTripsViewModel
    private let onSelect: ((RecentRoute) -> Void)?

    init(apiService: APIServiceProtocol, onSelect: ((RecentRoute) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: RecentTripsViewModel(apiService: apiService))
        self.onSelect = onSelect
    }

    var body: some View {
        content
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack {
                Spacer()
                ProgressView("加载中…")
                Spacer()
            }
            .frame(maxWidth: .infinity)
        case .loaded(let trips):
            List(Array(trips.enumerated()), id: \.element.id) { index, trip in
                Button {
                    onSelect?(trip)
                } label: { tripRow(trip) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("recent_trip_\(index)")
            }
            .listStyle(.plain)
            .refreshable { await viewModel.load() }
        case .empty:
            placeholder("还没有规划过路线", systemImage: "map")
        case .error(let message):
            placeholder(message, systemImage: "exclamationmark.triangle")
        }
    }

    private func tripRow(_ trip: RecentRoute) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .padding(.top, 5)
                Text(trip.origin.address ?? "起点").lineLimit(1)
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.top, 5)
                Text(trip.destination.address ?? "目的地").lineLimit(1)
            }
            HStack(spacing: 12) {
                if let dist = trip.totalDistanceKm {
                    Text("\(Int(dist)) km")
                }
                if let dur = trip.totalDurationMinutes {
                    Text(formatMinutes(dur))
                }
                Spacer()
                if let createdAt = trip.createdAt {
                    Text(formatDate(createdAt))
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分"
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            let display = DateFormatter()
            display.dateFormat = "MM-dd HH:mm"
            return display.string(from: date)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            let display = DateFormatter()
            display.dateFormat = "MM-dd HH:mm"
            return display.string(from: date)
        }
        return iso.prefix(10).description
    }

    private func placeholder(_ message: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: systemImage)
                .font(Tokens.typographyPlaceholderIconMd)
                .foregroundStyle(.tertiary)
            Text(message).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
