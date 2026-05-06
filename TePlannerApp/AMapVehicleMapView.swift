import SwiftUI
import MAMapKit

/// SwiftUI wrapper around `MAMapView` that recenters when the bound
/// coordinate changes and pins a marker at the vehicle's location.
struct AMapVehicleMapView: UIViewRepresentable {
    var coordinate: CLLocationCoordinate2D?
    var vehicleTitle: String
    var batteryLevel: Int?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MAMapView {
        let mapView = MAMapView()
        mapView.delegate = context.coordinator
        mapView.zoomLevel = 14
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.isShowsBuildings = false
        mapView.showsUserLocation = false
        return mapView
    }

    func updateUIView(_ mapView: MAMapView, context: Context) {
        guard let coordinate else { return }

        // Move camera if the coordinate jumped meaningfully.
        if context.coordinator.lastCoordinate == nil ||
            !approximatelyEqual(context.coordinator.lastCoordinate!, coordinate) {
            mapView.setCenter(coordinate, animated: true)
            context.coordinator.lastCoordinate = coordinate
        }

        // Refresh the marker (subtitle changes when battery changes).
        if let existing = context.coordinator.vehicleAnnotation {
            mapView.removeAnnotation(existing)
        }
        let annotation = MAPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = vehicleTitle
        if let battery = batteryLevel {
            annotation.subtitle = "电量 \(battery)%"
        }
        mapView.addAnnotation(annotation)
        context.coordinator.vehicleAnnotation = annotation
    }

    private func approximatelyEqual(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 1e-5 && abs(a.longitude - b.longitude) < 1e-5
    }

    final class Coordinator: NSObject, MAMapViewDelegate {
        var vehicleAnnotation: MAPointAnnotation?
        var lastCoordinate: CLLocationCoordinate2D?

        func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
            guard annotation is MAPointAnnotation else { return nil }
            let identifier = "vehicle"
            let view: MAPinAnnotationView
            if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MAPinAnnotationView {
                view = dequeued
                view.annotation = annotation
            } else {
                view = MAPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true
                view.animatesDrop = false
                view.pinColor = .purple
            }
            return view
        }
    }
}
