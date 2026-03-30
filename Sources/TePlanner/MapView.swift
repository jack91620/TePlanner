import SwiftUI
import MapKit

struct MapView: View {
    
    // The route plan to display on the map.
    // For now, it's optional. In a real app, you'd ensure this is passed in.
    let plan: RoutePlanResponse?

    // The state for the map's camera position.
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            
            // Draw the route polyline on the map if it exists.
            if let polylineCoordinates = plan?.polyline.map({ CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }), !polylineCoordinates.isEmpty {
                MapPolyline(coordinates: polylineCoordinates)
                    .stroke(.blue, lineWidth: 5)
            }

            // Add an annotation for the origin, if it exists.
            if let origin = plan?.origin, let lat = origin.lat, let lon = origin.lng {
                Annotation("出发地", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                    Image(systemName: "flag.fill")
                        .padding(8)
                        .foregroundStyle(.white)
                        .background(.green)
                        .clipShape(Circle())
                }
            }

            // Add an annotation for the destination.
            if let destination = plan?.destination, let lat = destination.lat, let lon = destination.lng {
                Annotation("目的地", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                    Image(systemName: "mappin.and.ellipse")
                        .padding(8)
                        .foregroundStyle(.white)
                        .background(.red)
                        .clipShape(Circle())
                }
            }
            
            // Add annotations for each charging stop.
            if let chargingStops = plan?.chargingStops {
                ForEach(chargingStops) { stop in
                    Annotation(stop.name, coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)) {
                        Image(systemName: "bolt.fill")
                            .padding(8)
                            .foregroundStyle(.white)
                            .background(.orange)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .onAppear(perform: calculateMapRegion)
        .navigationTitle("地图路线")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Calculates the appropriate map region to show the entire route.
    private func calculateMapRegion() {
        guard let plan = plan, !plan.polyline.isEmpty else { return }

        let coordinates = plan.polyline.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        
        // Find the bounding box of all coordinates.
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

        // Create a region from the bounding box.
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4, // Add some padding
            longitudeDelta: (maxLon - minLon) * 1.4 // Add some padding
        )
        
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// A preview provider for SwiftUI Canvas.
#Preview {
    // Create some mock data to display in the preview.
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
    
    return NavigationStack {
        MapView(plan: mockPlan)
    }
}
