import SwiftUI
import MAMapKit

/// Minimal SwiftUI wrapper around `MAMapView` to verify the AMap SDK is
/// wired correctly: API key valid, privacy compliance accepted, native
/// map renders. This is throwaway scaffolding — once HomeView lands it
/// becomes the production map.
struct AMapDemoView: View {
    var body: some View {
        AMapRepresentable()
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                Text("AMap SDK 验证")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 8)
            }
    }
}

private struct AMapRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MAMapView {
        let mapView = MAMapView()
        mapView.showsUserLocation = false
        mapView.zoomLevel = 12
        // Center over Shanghai by default — replaced with vehicle position
        // once HomeViewModel is wired in.
        mapView.setCenter(CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737), animated: false)
        return mapView
    }

    func updateUIView(_ uiView: MAMapView, context: Context) {}
}
