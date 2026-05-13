import SwiftUI
import TePlannerKit

/// "附近" tab content. Shows chargers near the bound coordinate
/// (vehicle's current position from HomeViewModel) with a horizontal
/// type-filter chip row at the top. Re-runs the search on filter
/// changes via `.onChange`.
struct NearbyChargersView: View {
    @StateObject private var viewModel: NearbyChargersViewModel
    private let coordinate: (latitude: Double, longitude: Double)?
    private let onSelect: ((ChargingStation) -> Void)?

    init(
        apiService: APIServiceProtocol,
        coordinate: (latitude: Double, longitude: Double)?,
        onSelect: ((ChargingStation) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: NearbyChargersViewModel(apiService: apiService))
        self.coordinate = coordinate
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterChips
            content
        }
        .task(id: coordinateKey) { await viewModel.load(near: coordinate) }
        .onChange(of: viewModel.selectedType) { _, _ in
            Task { await viewModel.load(near: coordinate) }
        }
    }

    private var coordinateKey: String {
        coordinate.map { "\($0.latitude),\($0.longitude)" } ?? "nil"
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("全部", value: nil)
                chip("超充", value: .supercharger)
                chip("目的地", value: .destination)
                chip("CCS", value: .ccs)
                chip("CHAdeMO", value: .chademo)
                chip("国标", value: .gbT)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ title: String, value: ChargingStationType?) -> some View {
        let selected = viewModel.selectedType == value
        return Button {
            viewModel.selectedType = value
        } label: {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color(.secondarySystemBackground),
                            in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .accessibilityIdentifier("nearby_filter_\(value?.rawValue ?? "all")")
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
        case .loaded(let stations):
            List(Array(stations.enumerated()), id: \.element.id) { index, station in
                Button {
                    onSelect?(station)
                } label: { stationRow(station) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("nearby_charger_\(index)")
            }
            .listStyle(.plain)
        case .empty:
            placeholder("附近没有充电站", systemImage: "bolt.slash")
        case .error(let message):
            placeholder(message, systemImage: "exclamationmark.triangle")
        }
    }

    private func stationRow(_ station: ChargingStation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: station.type))
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name).font(.body)
                if let address = station.address, !address.isEmpty {
                    Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 8) {
                    if let power = station.powerKw { Text("\(power) kW") }
                    if let total = station.totalStalls {
                        if let avail = station.availableStalls {
                            Text("\(avail)/\(total) 空闲").foregroundStyle(avail > 0 ? .green : .red)
                        } else {
                            Text("\(total) 桩")
                        }
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            Spacer()
            if let distance = station.distanceKm {
                Text(String(format: "%.1f km", distance))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func iconName(for type: ChargingStationType) -> String {
        switch type {
        case .supercharger: return "bolt.fill"
        case .destination: return "house.fill"
        case .ccs, .chademo, .gbT: return "powerplug.fill"
        case .other: return "bolt.car"
        }
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
