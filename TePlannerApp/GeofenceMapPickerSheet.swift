import SwiftUI
import TePlannerKit
import MAMapKit
import AMapSearchKit

/// Map-based picker for setting a geofence center + radius. Used by
/// the rule builder when triggerType == .geofence.
///
/// UX:
/// - Center is fixed at the screen center; user pans the map to move
///   it. Mirrors how 高德 / 美团 pick delivery addresses — way more
///   reliable than a draggable pin (no fat-finger).
/// - Radius slider at the bottom drives a translucent blue circle
///   overlay that shows the actual coverage area.
/// - Top has a search bar (POI keyword) that pans the map to the
///   first hit. '使用车辆位置' button uses the optional vehicle coord.
/// - Address line below the map updates via reverse-geocode whenever
///   the user stops panning for ~400 ms (debounced).
struct GeofenceMapPickerSheet: View {
    let initialLat: Double?
    let initialLng: Double?
    let initialRadiusM: Int
    let vehicleLat: Double?
    let vehicleLng: Double?
    let onConfirm: (_ lat: Double, _ lng: Double, _ radiusM: Int, _ address: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var center: CLLocationCoordinate2D = CLLocationCoordinate2D(
        latitude: 39.9042, longitude: 116.4074,
    )
    @State private var radiusM: Int = 200
    @State private var addressLabel: String = "正在定位…"
    @State private var searchText: String = ""
    @State private var searchResults: [POIResult] = []
    @State private var isSearching = false
    @State private var reverseGeocoder = AMapReverseGeocoder()
    @State private var debouncedReverseTask: Task<Void, Never>?

    private let apiService: APIServiceProtocol

    init(
        initialLat: Double?,
        initialLng: Double?,
        initialRadiusM: Int,
        vehicleLat: Double?,
        vehicleLng: Double?,
        apiService: APIServiceProtocol = APIService.shared,
        onConfirm: @escaping (Double, Double, Int, String) -> Void,
    ) {
        self.initialLat = initialLat
        self.initialLng = initialLng
        self.initialRadiusM = initialRadiusM
        self.vehicleLat = vehicleLat
        self.vehicleLng = vehicleLng
        self.apiService = apiService
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GeofenceMapView(
                    center: $center,
                    radiusM: radiusM,
                    onRegionStable: { lat, lng in
                        scheduleReverseGeocode(lat: lat, lng: lng)
                    },
                )
                .ignoresSafeArea(edges: [.bottom])

                // Center crosshair — visual anchor for "what point will
                // be saved". Pinned to screen center via overlay; the
                // map underneath is what moves.
                VStack(spacing: 0) {
                    Image(systemName: "mappin")
                        .font(.title)
                        .foregroundStyle(.green)
                        .shadow(radius: 2)
                    // 4-pt offset so the pin's tip lines up with the
                    // exact map center.
                    Circle()
                        .fill(Color.green.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .offset(y: -4)
                }
                .allowsHitTesting(false)

                VStack {
                    addressBanner
                    Spacer()
                    bottomPanel
                }
            }
            .navigationTitle("选择地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("使用此位置") {
                        onConfirm(
                            center.latitude, center.longitude,
                            radiusM, addressLabel == "正在定位…" ? "" : addressLabel,
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
            .searchable(text: $searchText, prompt: "搜索地址 / POI 名称")
            .onSubmit(of: .search) { Task { await runSearch() } }
            .onAppear {
                radiusM = initialRadiusM
                if let lat = initialLat, let lng = initialLng {
                    center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                } else if let lat = vehicleLat, let lng = vehicleLng {
                    center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }
                scheduleReverseGeocode(lat: center.latitude, lng: center.longitude)
            }
        }
    }

    @ViewBuilder
    private var addressBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .foregroundStyle(.green)
            Text(addressLabel)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("范围")
                    .font(.subheadline)
                Spacer()
                Text("\(radiusM) m")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(radiusM) },
                    set: { radiusM = Int($0 / 50) * 50 },
                ),
                in: 50...2000, step: 50,
            )
            HStack {
                if vehicleLat != nil, vehicleLng != nil {
                    Button {
                        if let lat = vehicleLat, let lng = vehicleLng {
                            center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                            scheduleReverseGeocode(lat: lat, lng: lng)
                        }
                    } label: {
                        Label("车辆位置", systemImage: "car.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Spacer()
                Text("拖动地图调整中心")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !searchResults.isEmpty {
                Divider()
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(searchResults.prefix(5)) { poi in
                            Button {
                                center = CLLocationCoordinate2D(
                                    latitude: poi.latitude, longitude: poi.longitude,
                                )
                                addressLabel = poi.address.isEmpty ? poi.name : "\(poi.name) · \(poi.address)"
                                searchResults = []
                                searchText = ""
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(poi.name).font(.subheadline.weight(.medium))
                                    Text(poi.address).font(.caption2).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(16)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    /// Trigger reverse-geocode once movement settles. ~400 ms after the
    /// last region-change emission. Cancels any in-flight task on
    /// subsequent stable-events so we never race two requests.
    private func scheduleReverseGeocode(lat: Double, lng: Double) {
        debouncedReverseTask?.cancel()
        debouncedReverseTask = Task {
            try? await Task.sleep(nanoseconds: 400 * 1_000_000)
            if Task.isCancelled { return }
            switch await apiService.reverseGeocode(latitude: lat, longitude: lng) {
            case .success(let resp):
                if let label = resp.displayName {
                    await MainActor.run { addressLabel = label }
                }
            case .failure:
                await MainActor.run { addressLabel = String(format: "%.5f, %.5f", lat, lng) }
            }
        }
    }

    private func runSearch() async {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        switch await apiService.geocode(address: q) {
        case .success(let result):
            await MainActor.run {
                let label = result.formattedAddress ?? result.address
                let poi = POIResult(
                    id: q, name: q, address: label,
                    latitude: result.latitude, longitude: result.longitude,
                )
                searchResults = [poi]
                center = CLLocationCoordinate2D(
                    latitude: result.latitude, longitude: result.longitude,
                )
                addressLabel = label
            }
        case .failure:
            break
        }
    }
}

/// Reverse geocoder placeholder — backend's /routes/reverse-geocode
/// already wraps AMap, so we just keep this struct around as a state
/// holder. The actual call goes through APIService.reverseGeocode.
private struct AMapReverseGeocoder {
    var lastLat: Double = 0
    var lastLng: Double = 0
}

// MARK: - UIViewRepresentable wrapping MAMapView with circle overlay.

private struct GeofenceMapView: UIViewRepresentable {
    @Binding var center: CLLocationCoordinate2D
    let radiusM: Int
    let onRegionStable: (Double, Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MAMapView {
        let mapView = MAMapView()
        mapView.delegate = context.coordinator
        mapView.zoomLevel = 15
        mapView.setCenter(center, animated: false)
        mapView.showsUserLocation = false
        mapView.showsCompass = false
        mapView.showsScale = false
        addCircle(on: mapView, context: context)
        context.coordinator.programmaticCenter = center
        return mapView
    }

    func updateUIView(_ mapView: MAMapView, context: Context) {
        let current = mapView.centerCoordinate
        let dlat = abs(current.latitude - center.latitude)
        let dlng = abs(current.longitude - center.longitude)
        if dlat > 0.00005 || dlng > 0.00005 {
            // External update (search hit / car-pos button) — pan map.
            context.coordinator.programmaticCenter = center
            mapView.setCenter(center, animated: true)
        }
        // Radius likely changed — refresh the circle overlay.
        if context.coordinator.lastRadiusM != radiusM {
            context.coordinator.lastRadiusM = radiusM
            removeCircles(on: mapView)
            addCircle(on: mapView, context: context)
        }
    }

    private func addCircle(on mapView: MAMapView, context: Context) {
        let circle = MACircle(center: center, radius: CLLocationDistance(radiusM))
        if let c = circle {
            mapView.add(c)
            context.coordinator.currentCircle = c
        }
    }

    private func removeCircles(on mapView: MAMapView) {
        if let overlays = mapView.overlays {
            for overlay in overlays {
                if let circle = overlay as? MACircle { mapView.remove(circle) }
            }
        }
    }

    final class Coordinator: NSObject, MAMapViewDelegate {
        var parent: GeofenceMapView
        var currentCircle: MACircle?
        var lastRadiusM: Int = -1
        /// Track whether the most recent center change came from
        /// SwiftUI (our update path) — if so, suppress the next
        /// region-stable callback to avoid feedback loops.
        var programmaticCenter: CLLocationCoordinate2D?

        init(parent: GeofenceMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MAMapView!, regionDidChangeAnimated animated: Bool) {
            let c = mapView.centerCoordinate
            // Suppress if this matches the programmatic update we just sent.
            if let p = programmaticCenter,
               abs(p.latitude - c.latitude) < 0.00005,
               abs(p.longitude - c.longitude) < 0.00005 {
                programmaticCenter = nil
                return
            }
            DispatchQueue.main.async {
                self.parent.center = c
                self.parent.onRegionStable(c.latitude, c.longitude)
                // Keep the circle overlay tracking the new center.
                if let mv = mapView, let old = self.currentCircle {
                    mv.remove(old)
                    if let circle = MACircle(center: c, radius: CLLocationDistance(self.parent.radiusM)) {
                        mv.add(circle)
                        self.currentCircle = circle
                    }
                }
            }
        }

        func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
            if let circle = overlay as? MACircle {
                let renderer = MACircleRenderer(circle: circle)
                renderer?.fillColor = UIColor.systemGreen.withAlphaComponent(0.18)
                renderer?.strokeColor = UIColor.systemGreen.withAlphaComponent(0.65)
                renderer?.lineWidth = 1.5
                return renderer
            }
            return nil
        }
    }
}
