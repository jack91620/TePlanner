import XCTest
import CoreLocation
@testable import TePlannerKit

/// Pin the GCJ-02 ↔ WGS-84 conversion math against known anchor
/// points. Numbers come from publicly-published GCJ-02 reference
/// implementations (open-source); within ~1 m of AMap's official
/// closed-source convertor.
final class CoordConverterTests: XCTestCase {

    // 北京天安门: WGS-84 (39.9087, 116.3974) ↔ GCJ-02 (39.9099, 116.4035)
    // — the canonical anchor every GCJ-02 lib pins against.
    private let tiananmenWGS = CLLocationCoordinate2D(latitude: 39.9087, longitude: 116.3974)
    private let tiananmenGCJ = CLLocationCoordinate2D(latitude: 39.9099, longitude: 116.4035)

    func test_wgs84_to_gcj02_known_anchor() {
        let out = CoordConverter.wgs84ToGcj02(tiananmenWGS)
        XCTAssertEqual(out.latitude, tiananmenGCJ.latitude, accuracy: 0.0005)
        XCTAssertEqual(out.longitude, tiananmenGCJ.longitude, accuracy: 0.0005)
    }

    func test_gcj02_to_wgs84_round_trip() {
        // Apply forward + inverse → should land within 1 cm of original.
        let gcj = CoordConverter.wgs84ToGcj02(tiananmenWGS)
        let wgs = CoordConverter.gcj02ToWgs84(gcj)
        XCTAssertEqual(wgs.latitude, tiananmenWGS.latitude, accuracy: 1e-7)
        XCTAssertEqual(wgs.longitude, tiananmenWGS.longitude, accuracy: 1e-7)
    }

    func test_offset_is_substantial_in_china() {
        // The whole reason we need the converter: in mainland China,
        // raw GPS coords are 50-500 m off when displayed on AMap.
        // Tiananmen offset should be > 50 m.
        let gcj = CoordConverter.wgs84ToGcj02(tiananmenWGS)
        let raw = CLLocation(latitude: tiananmenWGS.latitude, longitude: tiananmenWGS.longitude)
        let mapped = CLLocation(latitude: gcj.latitude, longitude: gcj.longitude)
        let meters = raw.distance(from: mapped)
        XCTAssertGreaterThan(meters, 50)
        XCTAssertLessThan(meters, 1500)  // sanity ceiling
    }

    func test_overseas_points_pass_through() {
        // SF: WGS-84 (37.7749, -122.4194). GCJ-02 only applies to
        // mainland China; out-of-range points must be unchanged so
        // overseas Teslas stay aligned.
        let sf = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let out = CoordConverter.wgs84ToGcj02(sf)
        XCTAssertEqual(out.latitude, sf.latitude, accuracy: 1e-9)
        XCTAssertEqual(out.longitude, sf.longitude, accuracy: 1e-9)
    }

    func test_inverse_overseas_pass_through() {
        let sf = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let out = CoordConverter.gcj02ToWgs84(sf)
        XCTAssertEqual(out.latitude, sf.latitude, accuracy: 1e-9)
        XCTAssertEqual(out.longitude, sf.longitude, accuracy: 1e-9)
    }

    func test_round_trip_at_shanghai() {
        // Outer Bund, Shanghai.
        let shanghai = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        let gcj = CoordConverter.wgs84ToGcj02(shanghai)
        let wgs = CoordConverter.gcj02ToWgs84(gcj)
        XCTAssertEqual(wgs.latitude, shanghai.latitude, accuracy: 1e-7)
        XCTAssertEqual(wgs.longitude, shanghai.longitude, accuracy: 1e-7)
    }
}
