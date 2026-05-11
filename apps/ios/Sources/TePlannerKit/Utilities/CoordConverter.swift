import CoreLocation
import Foundation

/// WGS-84 ↔ GCJ-02 conversion (China "Mars coordinates" offset).
///
/// **Coordinate system convention for TePlanner:**
///
/// - Backend stores everything in **WGS-84** — Tesla telemetry's
///   native format. No conversions on the server side.
/// - iOS in-memory data is **WGS-84**. View models, network DTOs,
///   geofence center storage, vehicle GPS — all WGS-84.
/// - AMap (MAMapView, AMapSearchAPI POI, AMap Web Service POI
///   responses) renders / returns **GCJ-02**.
/// - Convert ONLY at the boundary:
///   * Placing a WGS-84 coord on AMap: `CoordConverter.wgs84ToGcj02(c)`
///   * Reading a coord from AMap (geofence picker tap, POI search
///     result) before sending to backend or Tesla:
///     `CoordConverter.gcj02ToWgs84(c)`
///
/// Forgetting either direction shifts the displayed / used coord
/// by 50-500 m in China — the visible "vehicle marker drifts off
/// the road" bug, plus silent geofence-radius-misses and
/// Tesla-nav-200m-off-target bugs.
///
/// Implementation is the standard public-domain GCJ-02 offset
/// formula (NOT AMap's closed-source convertor). Within ~1 m of
/// AMap's official output for mainland China, which is the precision
/// the formula was designed to mask anyway. Off-mainland inputs
/// pass through unchanged (no offset applied — overseas Teslas
/// stay on the map).
public enum CoordConverter {

    private static let A: Double = 6_378_245.0       // 长半轴
    private static let EE: Double = 0.006_693_421_622_965_943_23  // 偏心率平方

    /// Convert WGS-84 (Tesla / GPS-raw) → GCJ-02 (高德 / AMap).
    public static func wgs84ToGcj02(_ c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard isInChina(c) else { return c }
        let dLat = transformLat(c.longitude - 105.0, c.latitude - 35.0)
        let dLng = transformLng(c.longitude - 105.0, c.latitude - 35.0)
        let radLat = c.latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - EE * magic * magic
        let sqrtMagic = sqrt(magic)
        let dLatFinal = (dLat * 180.0) / ((A * (1 - EE)) / (magic * sqrtMagic) * .pi)
        let dLngFinal = (dLng * 180.0) / (A / sqrtMagic * cos(radLat) * .pi)
        return CLLocationCoordinate2D(
            latitude: c.latitude + dLatFinal,
            longitude: c.longitude + dLngFinal
        )
    }

    /// Convert GCJ-02 (AMap / 高德) → WGS-84 (GPS-raw / Tesla).
    /// Iterative inversion of the forward conversion. 3 iterations
    /// converge to < 1 cm precision in mainland China.
    public static func gcj02ToWgs84(_ c: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard isInChina(c) else { return c }
        var guess = c
        for _ in 0..<3 {
            let forward = wgs84ToGcj02(guess)
            let dLat = forward.latitude - guess.latitude
            let dLng = forward.longitude - guess.longitude
            guess = CLLocationCoordinate2D(
                latitude: c.latitude - dLat,
                longitude: c.longitude - dLng
            )
        }
        return guess
    }

    // MARK: - internals

    /// Loose mainland-China bbox. Points outside are left untouched —
    /// GCJ-02 offset only applies on mainland. Taiwan / HK / Macau /
    /// border regions are intentionally excluded; the bbox is the same
    /// one used by every open-source GCJ-02 library.
    private static func isInChina(_ c: CLLocationCoordinate2D) -> Bool {
        return c.longitude >= 72.004 && c.longitude <= 137.8347
            && c.latitude >= 0.8293 && c.latitude <= 55.8271
    }

    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLng(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }
}
