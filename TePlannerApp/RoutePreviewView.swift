import SwiftUI
import TePlannerKit

/// Sheet that shows up after a destination is picked in SearchView.
/// Triggers `RoutePreviewViewModel.load()` on appear, renders a
/// summary + charging-stop list once the backend responds, and exposes
/// a "send to vehicle" CTA that hits `/vehicles/{id}/navigate`.
struct RoutePreviewView: View {
    @StateObject private var viewModel: RoutePreviewViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        apiService: APIServiceProtocol,
        destination: POIResult,
        origin: LocationInput?,
        currentSoc: Int?,
        vehicleId: String?
    ) {
        _viewModel = StateObject(wrappedValue: RoutePreviewViewModel(
            apiService: apiService,
            destination: destination,
            origin: origin,
            currentSoc: currentSoc,
            vehicleId: vehicleId
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("路线预览")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("关闭") { dismiss() }
                    }
                }
                .task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            VStack {
                Spacer()
                ProgressView("规划路线…").controlSize(.large)
                Spacer()
            }
        case .loaded(let plan):
            loadedView(plan)
        case .error(let message):
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text("路线规划失败")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("重试") { Task { await viewModel.load() } }
                    .buttonStyle(.bordered)
                Spacer()
            }
        }
    }

    private func loadedView(_ plan: RoutePlanResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard(plan)
                if !plan.warnings.isEmpty {
                    warningsCard(plan.warnings)
                }
                if !plan.chargingStops.isEmpty {
                    chargingStopsList(plan.chargingStops)
                }
                sendButton
            }
            .padding(16)
        }
    }

    private func summaryCard(_ plan: RoutePlanResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption2)
                    .padding(.top, 6)
                Text(plan.origin.name)
                    .lineLimit(1)
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption2)
                    .padding(.top, 6)
                Text(plan.destination.name)
                    .lineLimit(1)
            }
            Divider().padding(.vertical, 4)
            HStack(spacing: 18) {
                stat(value: "\(Int(plan.totalDistanceKm)) km", caption: "总距离")
                stat(value: formatMinutes(plan.totalDurationMinutes), caption: "总时长")
                stat(value: "\(plan.numChargingStops)", caption: "充电次数")
            }
            HStack(spacing: 18) {
                stat(value: "\(plan.initialSoc)% → \(plan.arrivalSoc)%", caption: "电量")
                if plan.chargingDurationMinutes > 0 {
                    stat(value: formatMinutes(plan.chargingDurationMinutes), caption: "充电时长")
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func warningsCard(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(warning).font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func chargingStopsList(_ stops: [ChargingStop]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("沿途充电站").font(.headline)
            ForEach(stops) { stop in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.tint)
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name).font(.body)
                        if let address = stop.address, !address.isEmpty {
                            Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        HStack(spacing: 12) {
                            Text("\(Int(stop.distanceFromStartKm)) km")
                            Text("\(stop.arrivalSoc)% → \(stop.departureSoc)%")
                            Text(formatMinutes(stop.chargingDurationMinutes))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var sendButton: some View {
        Button {
            Task { await viewModel.sendToVehicle() }
        } label: {
            sendButtonLabel
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.sendState == .sending || viewModel.sendState == .sent)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var sendButtonLabel: some View {
        switch viewModel.sendState {
        case .idle: Label("发送到车辆", systemImage: "paperplane.fill")
        case .sending: ProgressView()
        case .sent: Label("已发送", systemImage: "checkmark.circle.fill")
        case .failed(let message):
            VStack(spacing: 2) {
                Label("重新发送", systemImage: "exclamationmark.triangle")
                Text(message).font(.caption2)
            }
        }
    }

    private func stat(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分"
    }
}
