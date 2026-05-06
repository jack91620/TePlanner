import SwiftUI
import MAMapKit
import TePlannerKit

/// SwiftUI wrapper around `MAMapView` showing the vehicle marker and,
/// when a route plan is active, the planned polyline + charging-stop
/// pins. Camera follows the vehicle by default; once a route loads it
/// reframes to fit the whole trip.
struct AMapVehicleMapView: UIViewRepresentable {
    var coordinate: CLLocationCoordinate2D?
    var vehicleTitle: String
    var batteryLevel: Int?
    var route: RoutePlanResponse?

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
        let coordinator = context.coordinator
        let routeKey = route?.routeId.map(String.init) ?? (route == nil ? "nil" : "anon-\(route?.totalDistanceKm ?? 0)")

        updateVehicleMarker(on: mapView, coordinator: coordinator)

        if routeKey != coordinator.lastRouteKey {
            coordinator.lastRouteKey = routeKey
            renderRoute(on: mapView, coordinator: coordinator)
        }
    }

    private func updateVehicleMarker(on mapView: MAMapView, coordinator: Coordinator) {
        guard let coordinate else { return }

        // Refresh the marker (subtitle reflects current battery).
        if let existing = coordinator.vehicleAnnotation {
            mapView.removeAnnotation(existing)
        }
        let annotation = MAPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = vehicleTitle
        if let battery = batteryLevel {
            annotation.subtitle = "电量 \(battery)%"
        }
        mapView.addAnnotation(annotation)
        coordinator.vehicleAnnotation = annotation

        // Only auto-center on the vehicle when no route is active —
        // a route reframe handles its own camera fit.
        if route == nil,
           coordinator.lastCoordinate == nil ||
           !approximatelyEqual(coordinator.lastCoordinate!, coordinate) {
            mapView.setCenter(coordinate, animated: true)
            coordinator.lastCoordinate = coordinate
        }
    }

    private func renderRoute(on mapView: MAMapView, coordinator: Coordinator) {
        // Drop previously-rendered route artifacts.
        if !coordinator.routeOverlays.isEmpty {
            mapView.removeOverlays(coordinator.routeOverlays)
            coordinator.routeOverlays.removeAll()
        }
        if !coordinator.stopAnnotations.isEmpty {
            mapView.removeAnnotations(coordinator.stopAnnotations)
            coordinator.stopAnnotations.removeAll()
        }
        if let dest = coordinator.destinationAnnotation {
            mapView.removeAnnotation(dest)
            coordinator.destinationAnnotation = nil
        }

        guard let route else { return }

        // Polyline overlay.
        if !route.polyline.isEmpty {
            let cl2d = route.polyline.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            let polyline = cl2d.withUnsafeBufferPointer { buffer in
                MAPolyline(coordinates: UnsafeMutablePointer(mutating: buffer.baseAddress!),
                           count: UInt(cl2d.count))
            }
            if let polyline {
                mapView.add(polyline)
                coordinator.routeOverlays.append(polyline)
            }
        }

        // Charging-stop pins.
        for stop in route.chargingStops {
            let ann = ChargingStopAnnotation()
            ann.coordinate = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
            ann.title = stop.name
            ann.subtitle = "\(stop.arrivalSoc)% → \(stop.departureSoc)% · \(stop.chargingDurationMinutes) 分"
            mapView.addAnnotation(ann)
            coordinator.stopAnnotations.append(ann)
        }

        // Destination pin.
        if let destLat = route.destination.lat, let destLng = route.destination.lng {
            let ann = DestinationAnnotation()
            ann.coordinate = CLLocationCoordinate2D(latitude: destLat, longitude: destLng)
            ann.title = route.destination.name
            mapView.addAnnotation(ann)
            coordinator.destinationAnnotation = ann
        }

        // Reframe camera around the route.
        if !route.polyline.isEmpty {
            let lats = route.polyline.map(\.latitude)
            let lngs = route.polyline.map(\.longitude)
            if let minLat = lats.min(), let maxLat = lats.max(),
               let minLng = lngs.min(), let maxLng = lngs.max() {
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLng + maxLng) / 2
                )
                let span = MACoordinateSpan(
                    latitudeDelta: max(0.05, (maxLat - minLat) * 1.2),
                    longitudeDelta: max(0.05, (maxLng - minLng) * 1.2)
                )
                mapView.setRegion(MACoordinateRegion(center: center, span: span), animated: true)
            }
        }
    }

    private func approximatelyEqual(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 1e-5 && abs(a.longitude - b.longitude) < 1e-5
    }

    final class Coordinator: NSObject, MAMapViewDelegate {
        var vehicleAnnotation: MAPointAnnotation?
        var destinationAnnotation: DestinationAnnotation?
        var stopAnnotations: [ChargingStopAnnotation] = []
        var routeOverlays: [MAOverlay] = []
        var lastCoordinate: CLLocationCoordinate2D?
        var lastRouteKey: String?

        func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
            if annotation is ChargingStopAnnotation {
                return chargingStopView(for: annotation, on: mapView)
            }
            if annotation is DestinationAnnotation {
                return destinationView(for: annotation, on: mapView)
            }
            return vehicleView(for: annotation, on: mapView)
        }

        private func vehicleView(for annotation: MAAnnotation!, on mapView: MAMapView) -> MAAnnotationView {
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

        private func chargingStopView(for annotation: MAAnnotation!, on mapView: MAMapView) -> MAAnnotationView {
            let identifier = "charging-stop"
            let view: MAPinAnnotationView
            if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MAPinAnnotationView {
                view = dequeued
                view.annotation = annotation
            } else {
                view = MAPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true
                view.animatesDrop = false
                view.pinColor = .green
            }
            return view
        }

        private func destinationView(for annotation: MAAnnotation!, on mapView: MAMapView) -> MAAnnotationView {
            let identifier = "destination"
            let view: MAPinAnnotationView
            if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MAPinAnnotationView {
                view = dequeued
                view.annotation = annotation
            } else {
                view = MAPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true
                view.animatesDrop = false
                view.pinColor = .red
            }
            return view
        }

        func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
            guard let polyline = overlay as? MAPolyline else { return nil }
            let renderer = MAPolylineRenderer(polyline: polyline)
            renderer?.lineWidth = 6
            renderer?.strokeColor = UIColor.systemBlue
            renderer?.lineJoinType = kMALineJoinRound
            renderer?.lineCapType = kMALineCapRound
            return renderer
        }
    }
}

final class ChargingStopAnnotation: MAPointAnnotation {}
final class DestinationAnnotation: MAPointAnnotation {}
