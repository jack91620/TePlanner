import SwiftUI
import TePlannerKit
import UIKit

/// Bottom sheet shown when the user taps a row in the 附近 tab.
/// Surfaces whatever metadata the backend returned (operator, tel,
/// hours, ports, distance) and offers two outbound actions:
///
/// - 规划路线 — closes the sheet and asks the host (HomeView) to
///   open RoutePreviewView with this station as the destination.
/// - 在高德地图打开 — fires `iosamap://` URL scheme to launch the
///   installed AMap iOS app, falls back to the https://uri.amap.com
///   web entry point when AMap isn't installed.
struct ChargingStationDetailView: View {
    let station: ChargingStation
    let onPlanRoute: (ChargingStation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let address = station.address, !address.isEmpty {
                        infoRow(systemImage: "mappin.and.ellipse", text: address, primary: true)
                    }
                    infoBlock
                    actions
                }
                .padding(16)
            }
            .navigationTitle("充电站详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(station.name)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if let op = station.operatorName, !op.isEmpty {
                    badge(op, systemImage: "building.2", color: .accentColor)
                }
                badge(typeLabel, systemImage: typeIcon, color: typeColor)
                if station.open24h {
                    badge("24h", systemImage: "clock.fill", color: .green)
                }
            }
        }
    }

    @ViewBuilder
    private var infoBlock: some View {
        VStack(spacing: 0) {
            if let distance = station.distanceKm {
                infoRow(systemImage: "location",
                        text: formatDistance(distance),
                        caption: "距当前位置")
                Divider().padding(.vertical, 8)
            }
            if station.powerKw != nil || station.totalStalls != nil {
                infoRow(systemImage: "bolt.fill",
                        text: portsAndPowerText,
                        caption: "桩位 / 功率")
                Divider().padding(.vertical, 8)
            }
            if let hours = station.openHours, !hours.isEmpty {
                infoRow(systemImage: "clock", text: hours, caption: "营业时间")
                Divider().padding(.vertical, 8)
            }
            if let tel = station.tel, !tel.isEmpty {
                Button {
                    if let url = URL(string: "tel:\(tel.replacingOccurrences(of: " ", with: ""))") {
                        openURL(url)
                    }
                } label: {
                    infoRow(systemImage: "phone.fill", text: tel, caption: "联系电话",
                            valueColor: .accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                onPlanRoute(station)
                dismiss()
            } label: {
                Label("规划路线到此", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("station_plan_route_button")

            Button {
                openInAMap()
            } label: {
                Label("在高德地图打开", systemImage: "map")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("station_open_in_amap_button")
        }
    }

    private func openInAMap() {
        let lat = station.latitude
        let lng = station.longitude
        let name = station.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? station.name
        let amapScheme = "iosamap://path?sourceApplication=TePlanner&dlat=\(lat)&dlon=\(lng)&dname=\(name)&dev=0&t=0"
        let webFallback = "https://uri.amap.com/marker?position=\(lng),\(lat)&name=\(name)&src=teplanner"

        if let url = URL(string: amapScheme), UIApplication.shared.canOpenURL(url) {
            openURL(url)
        } else if let url = URL(string: webFallback) {
            openURL(url)
        }
    }

    // MARK: - Subviews

    private func badge(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private func infoRow(systemImage: String, text: String,
                         caption: String? = nil, primary: Bool = false,
                         valueColor: Color = .primary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .foregroundStyle(valueColor)
                    .font(primary ? .body : .body)
                if let caption {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Formatters

    private var portsAndPowerText: String {
        var parts: [String] = []
        if let total = station.totalStalls {
            if let avail = station.availableStalls {
                parts.append("\(avail) / \(total) 空闲")
            } else {
                parts.append("\(total) 桩位")
            }
        }
        if let power = station.powerKw {
            parts.append("\(power) kW")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private var typeLabel: String {
        switch station.type {
        case .supercharger: return "超充"
        case .destination: return "目的地"
        case .ccs: return "CCS"
        case .chademo: return "CHAdeMO"
        case .gbT: return "国标"
        case .other: return "充电站"
        }
    }

    private var typeIcon: String {
        switch station.type {
        case .supercharger: return "bolt.fill"
        case .destination: return "house.fill"
        case .ccs, .chademo, .gbT: return "powerplug.fill"
        case .other: return "bolt.car"
        }
    }

    private var typeColor: Color {
        switch station.type {
        case .supercharger: return .red
        case .destination: return .blue
        case .ccs, .chademo, .gbT: return .orange
        case .other: return .gray
        }
    }

    private func formatDistance(_ km: Double) -> String {
        if km < 1 { return String(format: "%.0f m", km * 1000) }
        return String(format: "%.1f km", km)
    }
}
