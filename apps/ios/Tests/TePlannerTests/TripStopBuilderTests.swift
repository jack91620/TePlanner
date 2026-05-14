import XCTest
@testable import TePlannerKit

/// Pins the `TripStop.stops(from: RoutePlanResponse)` contract.
///
/// Why this matters: a 2026-05-14 production audit found `active_trip`
/// totals=0 despite five phases of cron / SOC / off-route infrastructure
/// shipped. Root cause: the drawer's "发送到车辆" button called the
/// legacy single-destination nav API instead of `/trips/start`, so
/// `ActiveTrip` rows were never persisted and none of the multi-stop
/// machinery engaged. This test pins the new builder so a regression
/// silently slipping back to single-destination payloads gets caught.
final class TripStopBuilderTests: XCTestCase {

    private func plan(
        chargingStops: [ChargingStop] = [],
        destLat: Double? = 31.30,
        destLng: Double? = 121.50,
    ) -> RoutePlanResponse {
        RoutePlanResponse(
            routeId: 1,
            origin: LocationDetail(lat: 31.20, lng: 121.40, name: "起点"),
            destination: LocationDetail(lat: destLat, lng: destLng, name: "终点"),
            totalDistanceKm: 30,
            totalDurationMinutes: 30,
            drivingDurationMinutes: 20,
            chargingDurationMinutes: 10,
            chargingStops: chargingStops,
            numChargingStops: chargingStops.count,
            initialSoc: 50,
            arrivalSoc: 30,
            polyline: [
                Coordinate(latitude: 31.20, longitude: 121.40),
                Coordinate(latitude: 31.30, longitude: 121.50),
            ],
            warnings: []
        )
    }

    private func stop(_ id: String, lat: Double, lng: Double, arrivalSoc: Int = 25) -> ChargingStop {
        ChargingStop(
            stationId: id, name: "充电站\(id)", latitude: lat, longitude: lng,
            address: "addr-\(id)", operatorName: "Tesla",
            distanceFromStartKm: 10, arrivalSoc: arrivalSoc,
            departureSoc: 80, chargingDurationMinutes: 30
        )
    }

    func testReturnsNilWhenDestinationLacksCoordinates() {
        let p = plan(destLat: nil, destLng: nil)
        XCTAssertNil(TripStop.stops(from: p))
    }

    func testProducesFinalOnlyWhenNoChargingStops() {
        let p = plan(chargingStops: [])
        let identity: (Double, Double) -> (Double, Double) = { ($0, $1) }
        let stops = TripStop.stops(from: p, convert: identity)
        XCTAssertEqual(stops?.count, 1)
        XCTAssertEqual(stops?.last?.kind, .final)
        XCTAssertEqual(stops?.last?.latitude, 31.30)
        XCTAssertEqual(stops?.last?.longitude, 121.50)
        XCTAssertEqual(stops?.last?.name, "终点")
        XCTAssertNil(stops?.last?.stationId)
        XCTAssertNil(stops?.last?.socTarget)
    }

    func testChargingStopsPrecedeFinalInOrder() {
        let p = plan(chargingStops: [
            stop("A", lat: 31.22, lng: 121.42, arrivalSoc: 22),
            stop("B", lat: 31.26, lng: 121.46, arrivalSoc: 28),
        ])
        let identity: (Double, Double) -> (Double, Double) = { ($0, $1) }
        let stops = TripStop.stops(from: p, convert: identity)
        XCTAssertEqual(stops?.count, 3)
        XCTAssertEqual(stops?[0].kind, .charging)
        XCTAssertEqual(stops?[0].stationId, "A")
        XCTAssertEqual(stops?[0].socTarget, 22)
        XCTAssertEqual(stops?[1].kind, .charging)
        XCTAssertEqual(stops?[1].stationId, "B")
        XCTAssertEqual(stops?[2].kind, .final)
    }

    func testConvertHookIsAppliedToEveryStop() {
        let p = plan(chargingStops: [
            stop("A", lat: 31.22, lng: 121.42),
        ])
        var calls: [(Double, Double)] = []
        let stops = TripStop.stops(from: p) { lat, lng in
            calls.append((lat, lng))
            return (lat + 1.0, lng + 1.0)
        }
        XCTAssertEqual(calls.count, 2)  // 1 charging + 1 final
        XCTAssertEqual(stops?[0].latitude, 32.22)
        XCTAssertEqual(stops?[0].longitude, 122.42)
        XCTAssertEqual(stops?[1].latitude, 32.30)
        XCTAssertEqual(stops?[1].longitude, 122.50)
    }

    func testDefaultConvertShiftsByGcj02Offset() {
        // China mainland point — gcj02ToWgs84 should subtract the
        // characteristic ~200m offset.
        let p = plan(
            chargingStops: [],
            destLat: 31.2304, destLng: 121.4737,  // 上海
        )
        let stops = TripStop.stops(from: p)
        let final = stops?.last
        XCTAssertNotNil(final)
        // Offset is small but non-zero; pin only the magnitude so the
        // test survives the conversion algorithm tweaking precision.
        let dLat = abs((final?.latitude ?? 0) - 31.2304)
        let dLng = abs((final?.longitude ?? 0) - 121.4737)
        XCTAssertTrue(dLat > 0.0001 && dLat < 0.01, "lat offset \(dLat) out of expected band")
        XCTAssertTrue(dLng > 0.0001 && dLng < 0.01, "lng offset \(dLng) out of expected band")
    }
}
