import SwiftUI
import MapKit

public struct MapView: View {
    
    public let plan: RoutePlanResponse?

    public init(plan: RoutePlanResponse?) {
        self.plan = plan
    }

    // Use a simpler region state that is compatible with older OS versions.
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()

    public var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotationItems) { item in
            MapMarker(coordinate: item.coordinate, tint: item.tint)
        }
        .onAppear(perform: calculateMapRegion)
        .navigationTitle("地图路线")
        #if os(iOS)
        // This modifier is only available on iOS.
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    // A helper struct to represent annotations on the map.
    private struct AnnotationItem: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let tint: Color
    }

    // Computed property to generate annotation items from the route plan.
    private var annotationItems: [AnnotationItem] {
        var items: [AnnotationItem] = []
        
        if let origin = plan?.origin, let lat = origin.lat, let lon = origin.lng {
            items.append(AnnotationItem(coordinate: .init(latitude: lat, longitude: lon), tint: .green))
        }

        if let destination = plan?.destination, let lat = destination.lat, let lon = destination.lng {
            items.append(AnnotationItem(coordinate: .init(latitude: lat, longitude: lon), tint: .red))
        }
        
        plan?.chargingStops.forEach { stop in
            items.append(AnnotationItem(coordinate: .init(latitude: stop.latitude, longitude: stop.longitude), tint: .orange))
        }
        
        return items
    }
    
    private func calculateMapRegion() {
        guard let plan = plan, !plan.polyline.isEmpty else { return }

        let coordinates = plan.polyline.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        
        var minLat = coordinates.first!.latitude
        var maxLat = coordinates.first!.latitude
        var minLon = coordinates.first!.longitude
        var maxLon = coordinates.first!.longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4,
            longitudeDelta: (maxLon - minLon) * 1.4
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
}

// Revert to the older, more compatible PreviewProvider struct.
struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        let mockPlan = RoutePlanResponse(
            routeId: 1,
            origin: LocationDetail(lat: 39.9042, lng: 116.4074, name: "Beijing"),
            destination: LocationDetail(lat: 31.2304, lng: 121.4737, name: "Shanghai"),
            totalDistanceKm: 1200,
            totalDurationMinutes: 960,
            drivingDurationMinutes: 840,
            chargingDurationMinutes: 120,
            chargingStops: [
                ChargingStop(stationId: "cs1", name: "Jinan Supercharger", latitude: 36.668, longitude: 117.02, address: "Jinan", operatorName: "Tesla", distanceFromStartKm: 400, arrivalSoc: 25, departureSoc: 80, chargingDurationMinutes: 60),
                ChargingStop(stationId: "cs2", name: "Xuzhou Supercharger", latitude: 34.26, longitude: 117.2, address: "Xuzhou", operatorName: "Tesla", distanceFromStartKm: 800, arrivalSoc: 30, departureSoc: 80, chargingDurationMinutes: 60)
            ],
            numChargingStops: 2,
            initialSoc: 100,
            arrivalSoc: 20,
            polyline: [
                Coordinate(latitude: 39.9042, longitude: 116.4074),
                Coordinate(latitude: 36.668, longitude: 117.02),
                Coordinate(latitude: 34.26, longitude: 117.2),
                Coordinate(latitude: 31.2304, longitude: 121.4737)
            ],
            warnings: []
        )
        
        NavigationStack {
            MapView(plan: mockPlan)
        }
    }
}
