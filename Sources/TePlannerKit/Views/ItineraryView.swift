import SwiftUI

public struct ItineraryView: View {
    public let plan: RoutePlanResponse

    public init(plan: RoutePlanResponse) {
        self.plan = plan
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Origin Point
            ItineraryRow(
                icon: "flag.fill",
                iconColor: .green,
                title: "出发地",
                subtitle: plan.origin.name,
                detail: "出发时电量: \(plan.initialSoc)%"
            )
            
            // Loop through charging stops if any exist
            if !plan.chargingStops.isEmpty {
                ForEach(0..<plan.chargingStops.count, id: \.self) { index in
                    let stop = plan.chargingStops[index]
                    
                    // Driving segment
                    HStack {
                        VStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2)
                        }
                        .frame(width: 30) // Match icon width of ItineraryRow
                        
                        Text("行驶约 \(String(format: "%.1f", stop.distanceFromStartKm)) km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                        
                        Spacer()
                    }
                    
                    // Charging Stop
                    ItineraryRow(
                        icon: "bolt.fill",
                        iconColor: .orange,
                        title: stop.name,
                        subtitle: "\(stop.operatorName ?? "未知运营商") - \(stop.address ?? "")",
                        detail: "到达电量: \(stop.arrivalSoc)% \n充电 \(stop.chargingDurationMinutes) 分钟 \n离开电量: \(stop.departureSoc)%"
                    )
                }
                
                // Final driving segment after last stop
                if let lastStop = plan.chargingStops.last {
                    let remainingDistance = plan.totalDistanceKm - lastStop.distanceFromStartKm
                    HStack {
                        VStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2)
                        }
                        .frame(width: 30)
                        
                        Text("行驶约 \(String(format: "%.1f", remainingDistance)) km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                }
            } else {
                 // No stops, just one long drive
                 HStack {
                    VStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2)
                    }
                    .frame(width: 30)
                    
                    Text("直达行驶 \(String(format: "%.1f", plan.totalDistanceKm)) km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                    Spacer()
                }
            }
            
            // Destination Point
            ItineraryRow(
                icon: "mappin.and.ellipse",
                iconColor: .red,
                title: "目的地",
                subtitle: plan.destination.name,
                detail: "预计到达电量: \(plan.arrivalSoc)%"
            )
        }
        .padding(.vertical, 8)
    }
}

struct ItineraryRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 30, alignment: .center)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

// A simple preview
#if DEBUG
struct ItineraryView_Previews: PreviewProvider {
    static var previews: some View {
        let mockPlan = RoutePlanResponse(
            routeId: 1,
            origin: LocationDetail(lat: 39.9, lng: 116.4, name: "北京市朝阳区"),
            destination: LocationDetail(lat: 31.2, lng: 121.4, name: "上海市黄浦区"),
            totalDistanceKm: 1210.5,
            totalDurationMinutes: 850,
            drivingDurationMinutes: 720,
            chargingDurationMinutes: 130,
            chargingStops: [
                ChargingStop(stationId: "1", name: "济南服务区超级充电站", latitude: 36.6, longitude: 117.0, address: "京沪高速", operatorName: "Tesla", distanceFromStartKm: 410.2, arrivalSoc: 15, departureSoc: 85, chargingDurationMinutes: 50),
                 ChargingStop(stationId: "2", name: "徐州服务区国家电网", latitude: 34.2, longitude: 117.2, address: "京沪高速", operatorName: "国家电网", distanceFromStartKm: 850.5, arrivalSoc: 20, departureSoc: 80, chargingDurationMinutes: 80)
            ],
            numChargingStops: 2,
            initialSoc: 100,
            arrivalSoc: 22,
            polyline: [],
            warnings: []
        )
        
        ScrollView {
            ItineraryView(plan: mockPlan)
                .padding()
        }
    }
}
#endif
