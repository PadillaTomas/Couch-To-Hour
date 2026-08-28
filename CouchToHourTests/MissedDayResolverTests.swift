import XCTest
@testable import CouchToHour

final class MissedDayResolverTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// Mon 2026-01-05 start, Week-1 schedule: D1 Mon 5th, D2 Wed 7th, D3 Fri 9th.
    private lazy var slots = ScheduleGenerator.schedule(
        startingWeek: 1, startWeekday: 2, anchor: date(2026, 1, 5), calendar: calendar
    )

    func testOnTrackWhenTodayHasASessionAndNothingMissed() {
        let r = MissedDayResolver.resolve(today: date(2026, 1, 5), slots: slots,
                                          isComplete: { _, _ in false }, calendar: calendar)
        XCTAssertEqual(r, .onTrack(week: 1, day: 1))
    }

    func testRestWhenNoSessionTodayAndCaughtUp() {
        // Tue 6th: no session; D1 on the 5th already done.
        let r = MissedDayResolver.resolve(today: date(2026, 1, 6), slots: slots,
                                          isComplete: { w, d in (w, d) == (1, 1) }, calendar: calendar)
        XCTAssertEqual(r, .rest)
    }

    func testMissedWithASessionAlsoDueToday() {
        // Wed 7th: D1 (Mon) never done, D2 is today.
        let r = MissedDayResolver.resolve(today: date(2026, 1, 7), slots: slots,
                                          isComplete: { _, _ in false }, calendar: calendar)
        XCTAssertEqual(r, .missed(missedWeek: 1, missedDay: 1, currentWeek: 1, currentDay: 2))
    }

    func testMissedWithNoSessionToday() {
        // Thu 8th: D1 (Mon) missed, nothing scheduled today.
        let r = MissedDayResolver.resolve(today: date(2026, 1, 8), slots: slots,
                                          isComplete: { w, d in (w, d) == (1, 2) }, calendar: calendar)
        XCTAssertEqual(r, .missed(missedWeek: 1, missedDay: 1, currentWeek: nil, currentDay: nil))
    }

    func testMissedReportsEarliestOutstandingSession() {
        // Fri 9th: D1 and D2 both missed → earliest (D1) is the one to prompt.
        let r = MissedDayResolver.resolve(today: date(2026, 1, 9), slots: slots,
                                          isComplete: { _, _ in false }, calendar: calendar)
        XCTAssertEqual(r, .missed(missedWeek: 1, missedDay: 1, currentWeek: 1, currentDay: 3))
    }

    func testPlanCompleteWhenEverythingDone() {
        let r = MissedDayResolver.resolve(today: date(2026, 3, 1), slots: slots,
                                          isComplete: { _, _ in true }, calendar: calendar)
        XCTAssertEqual(r, .planComplete)
    }

    func testEmptyScheduleIsRest() {
        let r = MissedDayResolver.resolve(today: date(2026, 1, 5), slots: [],
                                          isComplete: { _, _ in false }, calendar: calendar)
        XCTAssertEqual(r, .rest)
    }
}
