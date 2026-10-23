import XCTest
@testable import DaylightCore

final class CountdownTests: XCTestCase {
    private func calendar(_ zone: String = "America/Costa_Rica") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testDefaultIsThirtyCalendarDaysAhead() {
        let cal = calendar()
        let now = date(2026, 10, 21, 14, calendar: cal)
        let countdown = Countdown(now: now, calendar: cal)
        XCTAssertEqual(countdown.target, LocalDay(year: 2026, month: 11, day: 20))
        XCTAssertEqual(countdown.snapshot(at: now, calendar: cal).days, 30)
    }

    func testTomorrowRemainsOneDayAt2359() {
        let cal = calendar()
        let now = date(2026, 10, 21, 23, 59, calendar: cal)
        var countdown = Countdown(now: now, calendar: cal)
        countdown.target = LocalDay(year: 2026, month: 10, day: 22)
        let state = countdown.snapshot(at: now, calendar: cal)
        XCTAssertEqual(state.days, 1)
        XCTAssertEqual(state.caption, "day to go")
        XCTAssertEqual(state.fullDays, 0)
        XCTAssertEqual(state.hours, 0)
        XCTAssertEqual(state.minutes, 1)
    }

    func testTodayAndPastNeverGoNegative() {
        let cal = calendar()
        let now = date(2026, 10, 21, 14, calendar: cal)
        var countdown = Countdown(now: now, calendar: cal)
        countdown.target = LocalDay(now, calendar: cal)
        let today = countdown.snapshot(at: now, calendar: cal)
        XCTAssertTrue(today.isToday)
        XCTAssertEqual(today.days, 0)
        XCTAssertEqual(today.remainingFraction, 0)
        countdown.target = LocalDay(year: 2026, month: 10, day: 20)
        let past = countdown.snapshot(at: now, calendar: cal)
        XCTAssertTrue(past.hasPassed)
        XCTAssertFalse(past.isToday)
        XCTAssertEqual(past.days, 0)
        XCTAssertEqual(past.fullDays, 0)
        XCTAssertEqual(past.hours, 0)
        XCTAssertEqual(past.minutes, 0)
    }

    func testSpringDSTUsesCalendarDays() {
        let cal = calendar("America/New_York")
        let now = date(2026, 3, 7, calendar: cal)
        var countdown = Countdown(now: now, calendar: cal)
        countdown.target = LocalDay(year: 2026, month: 3, day: 9)
        XCTAssertEqual(countdown.target.date(in: cal).timeIntervalSince(now), 47 * 3600)
        XCTAssertEqual(countdown.snapshot(at: now, calendar: cal).days, 2)
        XCTAssertEqual(countdown.snapshot(at: now, calendar: cal).fullDays, 2)
    }

    func testFallDSTUsesCalendarDays() {
        let cal = calendar("America/New_York")
        let now = date(2026, 10, 31, calendar: cal)
        var countdown = Countdown(now: now, calendar: cal)
        countdown.target = LocalDay(year: 2026, month: 11, day: 2)
        XCTAssertEqual(countdown.target.date(in: cal).timeIntervalSince(now), 49 * 3600)
        XCTAssertEqual(countdown.snapshot(at: now, calendar: cal).days, 2)
    }

    func testLeapDayAndYearBoundary() {
        let cal = calendar()
        let now = date(2028, 2, 28, calendar: cal)
        var countdown = Countdown(now: now, calendar: cal)
        countdown.target = LocalDay(year: 2028, month: 3, day: 1)
        XCTAssertEqual(countdown.snapshot(at: now, calendar: cal).days, 2)
        countdown.target = LocalDay(year: 2027, month: 1, day: 1)
        XCTAssertEqual(countdown.snapshot(at: date(2026, 12, 31, calendar: cal), calendar: cal).days, 1)
    }

    func testLocalDateSurvivesTimeZoneChange() {
        let day = LocalDay(year: 2026, month: 11, day: 20)
        for zone in ["America/Costa_Rica", "Asia/Tokyo", "Pacific/Honolulu"] {
            let cal = calendar(zone)
            XCTAssertEqual(LocalDay(day.date(in: cal), calendar: cal), day)
        }
    }

    func testRingDrainsAndClamps() {
        let cal = calendar()
        let start = date(2026, 10, 1, calendar: cal)
        var countdown = Countdown(now: start, calendar: cal)
        countdown.target = LocalDay(year: 2026, month: 10, day: 11)
        XCTAssertEqual(countdown.snapshot(at: start, calendar: cal).remainingFraction, 1)
        XCTAssertEqual(countdown.snapshot(at: date(2026, 10, 6, calendar: cal), calendar: cal).remainingFraction, 0.5)
        XCTAssertEqual(countdown.snapshot(at: date(2026, 9, 1, calendar: cal), calendar: cal).remainingFraction, 1)
        XCTAssertEqual(countdown.snapshot(at: date(2026, 10, 12, calendar: cal), calendar: cal).remainingFraction, 0)
        countdown.started = countdown.target
        XCTAssertEqual(countdown.snapshot(at: start, calendar: cal).remainingFraction, 0)
    }

    func testFlipRemainder() {
        let cal = calendar()
        let now = date(2026, 10, 21, 9, 15, calendar: cal)
        var countdown = Countdown(now: now, calendar: cal)
        countdown.target = LocalDay(year: 2026, month: 10, day: 24)
        let state = countdown.snapshot(at: now, calendar: cal)
        XCTAssertEqual(state.days, 3)
        XCTAssertEqual(state.fullDays, 2)
        XCTAssertEqual(state.hours, 14)
        XCTAssertEqual(state.minutes, 45)
    }

    func testEmptyTitleFallsBack() {
        var countdown = Countdown()
        countdown.title = " \n "
        XCTAssertEqual(countdown.displayTitle, "My next big day")
        countdown.title = " A special day "
        XCTAssertEqual(countdown.displayTitle, "A special day")
    }

    func testInvalidCivilDatesRejected() {
        XCTAssertFalse(LocalDay(year: 2026, month: 2, day: 30).isValid(in: calendar()))
        XCTAssertFalse(LocalDay(year: 2026, month: 13, day: 1).isValid(in: calendar()))
        XCTAssertTrue(LocalDay(year: 2028, month: 2, day: 29).isValid(in: calendar()))
    }

    func testPersistenceRoundTrip() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("countdown.json")
        var value = Countdown()
        value.title = "A long title with unicode 🌞"
        value.style = .flip; value.theme = .forest; value.accent = .mint; value.size = .large
        value.alwaysOnTop = true; value.allSpaces = true
        try CountdownFile.write(value, to: url)
        XCTAssertEqual(try CountdownFile.read(from: url), value)
        value.title = "Updated"
        try CountdownFile.write(value, to: url)
        XCTAssertEqual(try CountdownFile.read(from: url).title, "Updated")
    }

    func testCorruptFileIsNotOverwrittenOnRead() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let bad = Data("not json".utf8)
        try bad.write(to: url)
        XCTAssertThrowsError(try CountdownFile.read(from: url))
        XCTAssertEqual(try Data(contentsOf: url), bad)
    }

    func testInvalidWriteDoesNotReplaceExistingData() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("countdown.json")
        let valid = Countdown()
        try CountdownFile.write(valid, to: url)
        var invalid = valid
        invalid.target = LocalDay(year: 2026, month: 2, day: 30)
        XCTAssertThrowsError(try CountdownFile.write(invalid, to: url))
        XCTAssertEqual(try CountdownFile.read(from: url), valid)
    }
}
