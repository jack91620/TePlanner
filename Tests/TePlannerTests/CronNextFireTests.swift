import XCTest
@testable import TePlannerKit

/// `RuleDisplay.nextCronFire` powers the rule-detail page's '下次触发'
/// label and may later be reused to schedule local cron previews.
/// These tests pin the supported expression shapes:
///   - 'M H * * *'         → daily
///   - 'M H * * 1-5'       → weekdays
///   - 'M H * * 0,6'       → weekend
///   - 'M H * * 1,3,5'     → comma-separated
final class CronNextFireTests: XCTestCase {
    private let tz = TimeZone(identifier: "Asia/Shanghai")!

    private func makeSpec(_ expr: String) -> RuleSpec {
        return [
            "trigger": .object([
                "type": .string("cron"),
                "expr": .string(expr),
            ]),
        ]
    }

    /// Build a Date in Asia/Shanghai for unambiguous comparison.
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        return cal.date(from: c)!
    }

    func test_dailyAt_730_fromBeforeFire_returnsToday() {
        // Reference: 2026-05-08 (Friday) 06:00 Shanghai
        let ref = date(2026, 5, 8, 6, 0)
        let next = RuleDisplay.nextCronFire(
            spec: makeSpec("30 7 * * *"),
            referenceDate: ref, timeZone: tz,
        )
        XCTAssertEqual(next, date(2026, 5, 8, 7, 30))
    }

    func test_dailyAt_730_fromAfterFire_returnsTomorrow() {
        // Reference: 2026-05-08 (Friday) 08:00 — already past 7:30
        let ref = date(2026, 5, 8, 8, 0)
        let next = RuleDisplay.nextCronFire(
            spec: makeSpec("30 7 * * *"),
            referenceDate: ref, timeZone: tz,
        )
        XCTAssertEqual(next, date(2026, 5, 9, 7, 30))
    }

    func test_weekdaysOnly_fromSaturday_skipsToMonday() {
        // 2026-05-09 is Saturday — workday cron should jump to Monday 5/11.
        let ref = date(2026, 5, 9, 6, 0)
        let next = RuleDisplay.nextCronFire(
            spec: makeSpec("30 7 * * 1-5"),
            referenceDate: ref, timeZone: tz,
        )
        XCTAssertEqual(next, date(2026, 5, 11, 7, 30))
    }

    func test_weekendOnly_fromMonday_skipsToSaturday() {
        // 2026-05-11 Monday — weekend cron should jump to Saturday 5/16.
        let ref = date(2026, 5, 11, 6, 0)
        let next = RuleDisplay.nextCronFire(
            spec: makeSpec("0 9 * * 0,6"),
            referenceDate: ref, timeZone: tz,
        )
        XCTAssertEqual(next, date(2026, 5, 16, 9, 0))
    }

    func test_commaSeparatedDays_picksNearest() {
        // 2026-05-08 (Friday). '1,3,5' = Mon/Wed/Fri. Same-day Fri 7:30
        // is past 6:00 ref → fires today.
        let ref = date(2026, 5, 8, 6, 0)
        let next = RuleDisplay.nextCronFire(
            spec: makeSpec("30 7 * * 1,3,5"),
            referenceDate: ref, timeZone: tz,
        )
        XCTAssertEqual(next, date(2026, 5, 8, 7, 30))
    }

    func test_nonCronRule_returnsNil() {
        let spec: RuleSpec = [
            "trigger": .object([
                "type": .string("state_duration"),
                "for_minutes": .int(120),
            ]),
        ]
        XCTAssertNil(RuleDisplay.nextCronFire(spec: spec))
    }

    func test_invalidCron_returnsNil() {
        XCTAssertNil(RuleDisplay.nextCronFire(spec: makeSpec("not a cron")))
        XCTAssertNil(RuleDisplay.nextCronFire(spec: makeSpec("30 7 1 5 *"))) // dom/month set
        XCTAssertNil(RuleDisplay.nextCronFire(spec: makeSpec("30 7 * * 9"))) // bad weekday
    }
}
