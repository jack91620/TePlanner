import XCTest
@testable import TePlannerKit

final class ChargeLimitSuggesterTests: XCTestCase {
    private var settings: InMemorySettingsStore!
    private var clock: Date!

    override func setUp() async throws {
        settings = InMemorySettingsStore()
        clock = Date(timeIntervalSince1970: 1_700_000_000)
    }

    func testRecommendsDailyWhenNoUpcomingTrip() {
        settings.dailyChargeLimitSoc = 70
        let s = ChargeLimitSuggester.suggest(
            currentLimit: 90,
            settings: settings,
            upcomingDeparture: nil,
            now: clock
        )
        XCTAssertEqual(s.recommendedPercent, 70)
        XCTAssertEqual(s.reason, .daily)
        XCTAssertFalse(s.alreadyMatches)
    }

    func testRecommendsTripWhenDepartureWithinWindow() {
        settings.tripChargeLimitSoc = 90
        let dep = ScheduledDeparture(
            departureAt: clock.addingTimeInterval(6 * 3600),
            vehicleId: "v1"
        )
        let s = ChargeLimitSuggester.suggest(
            currentLimit: 70,
            settings: settings,
            upcomingDeparture: dep,
            now: clock
        )
        XCTAssertEqual(s.recommendedPercent, 90)
        if case .upcomingDeparture(let hours) = s.reason {
            XCTAssertEqual(hours, 6)
        } else {
            XCTFail("expected .upcomingDeparture, got \(s.reason)")
        }
    }

    func testFallsBackToDailyWhenDepartureBeyondWindow() {
        settings.dailyChargeLimitSoc = 70
        let dep = ScheduledDeparture(
            departureAt: clock.addingTimeInterval(48 * 3600),  // 2 days out
            vehicleId: "v1"
        )
        let s = ChargeLimitSuggester.suggest(
            currentLimit: nil,
            settings: settings,
            upcomingDeparture: dep,
            now: clock,
            tripWindowHours: 12
        )
        XCTAssertEqual(s.reason, .daily,
                       "departure too far out shouldn't elevate the recommendation")
        XCTAssertEqual(s.recommendedPercent, 70)
    }

    func testHidesWhenCurrentMatchesRecommendation() {
        settings.dailyChargeLimitSoc = 80
        let s = ChargeLimitSuggester.suggest(
            currentLimit: 80,
            settings: settings,
            upcomingDeparture: nil,
            now: clock
        )
        XCTAssertTrue(s.alreadyMatches,
                      "no point nudging the user when the car is already at the recommended limit")
    }

    func testNoCurrentLimitNeverMatches() {
        let s = ChargeLimitSuggester.suggest(
            currentLimit: nil,
            settings: settings,
            upcomingDeparture: nil,
            now: clock
        )
        XCTAssertFalse(s.alreadyMatches)
    }

    func testPastDepartureIgnored() {
        let dep = ScheduledDeparture(
            departureAt: clock.addingTimeInterval(-3600),  // 1h ago
            vehicleId: "v1"
        )
        let s = ChargeLimitSuggester.suggest(
            currentLimit: 70,
            settings: settings,
            upcomingDeparture: dep,
            now: clock
        )
        XCTAssertEqual(s.reason, .daily,
                       "stale departure should be ignored")
    }
}
