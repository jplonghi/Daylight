import XCTest
@testable import DaylightCore

final class DayGridTests: XCTestCase {
    private func calendar(_ zone: String = "America/Costa_Rica") -> Calendar {
        var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(identifier: zone)!; return value
    }
    private func countdown(start: LocalDay, target: LocalDay) -> Countdown {
        var value = Countdown(); value.started = start; value.target = target; value.style = .grid; return value
    }
    func testEachSquareRepresentsOneCivilDayAndTodayIsOutlined() {
        let cal = calendar()
        let value = countdown(start: LocalDay(year: 2026, month: 10, day: 1), target: LocalDay(year: 2026, month: 10, day: 31))
        let state = value.dayGrid(at: LocalDay(year: 2026, month: 10, day: 16).date(in: cal), calendar: cal)
        XCTAssertEqual(state.totalDays, 30); XCTAssertEqual(state.cellCount, 30)
        XCTAssertEqual(state.elapsedDays, 15); XCTAssertEqual(state.daysPerCell, 1); XCTAssertEqual(state.currentCell, 15)
        XCTAssertTrue((0..<15).allSatisfy { state.completion(of: $0) == 1 })
        XCTAssertTrue((15..<30).allSatisfy { state.completion(of: $0) == 0 })
    }
    func testFutureStartHasNoElapsedDaysOrCurrentCell() {
        let cal = calendar()
        let value = countdown(start: LocalDay(year: 2026, month: 11, day: 1), target: LocalDay(year: 2026, month: 11, day: 11))
        let state = value.dayGrid(at: LocalDay(year: 2026, month: 10, day: 22).date(in: cal), calendar: cal)
        XCTAssertEqual(state.totalDays, 10); XCTAssertEqual(state.elapsedDays, 0); XCTAssertNil(state.currentCell)
    }
    func testTargetDayAndPastDatesAreFullyBright() {
        let cal = calendar()
        let value = countdown(start: LocalDay(year: 2026, month: 10, day: 1), target: LocalDay(year: 2026, month: 10, day: 22))
        for day in [22, 23] {
            let state = value.dayGrid(at: LocalDay(year: 2026, month: 10, day: day).date(in: cal), calendar: cal)
            XCTAssertEqual(state.elapsedDays, state.totalDays); XCTAssertNil(state.currentCell)
            XCTAssertTrue((0..<state.cellCount).allSatisfy { state.completion(of: $0) == 1 })
        }
    }
    func testDaylightSavingUsesDaysRatherThanTwentyFourHourBlocks() {
        let cal = calendar("America/New_York")
        for month in [3, 11] {
            let start = LocalDay(year: 2026, month: month, day: 1)
            let target = LocalDay(year: 2026, month: month, day: 15)
            let now = cal.date(byAdding: .hour, value: 12, to: LocalDay(year: 2026, month: month, day: 10).date(in: cal))!
            let state = countdown(start: start, target: target).dayGrid(at: now, calendar: cal)
            XCTAssertEqual(state.totalDays, 14); XCTAssertEqual(state.elapsedDays, 9)
        }
    }
    func testGroupedCellsPreservePartialAndShortFinalBucket() {
        let cal = calendar()
        let value = countdown(start: LocalDay(year: 2026, month: 10, day: 1), target: LocalDay(year: 2026, month: 10, day: 12))
        let state = value.dayGrid(at: LocalDay(year: 2026, month: 10, day: 11).date(in: cal), calendar: cal, maxCells: 3)
        XCTAssertEqual(state.totalDays, 11); XCTAssertEqual(state.daysPerCell, 4); XCTAssertEqual(state.cellCount, 3)
        XCTAssertEqual(state.completion(of: 0), 1); XCTAssertEqual(state.completion(of: 1), 1)
        XCTAssertEqual(state.completion(of: 2), 2.0 / 3.0, accuracy: 0.00001)
        XCTAssertEqual(state.completion(of: -1), 0); XCTAssertEqual(state.completion(of: 3), 0)
    }
    func testExtremeAndReversedTimelinesStayBounded() {
        let cal = calendar()
        let now = LocalDay(year: 2026, month: 10, day: 22).date(in: cal)
        let huge = countdown(start: LocalDay(year: 1900, month: 1, day: 1), target: LocalDay(year: 9999, month: 12, day: 31))
        XCTAssertLessThanOrEqual(huge.dayGrid(at: now, calendar: cal).cellCount, 600)
        XCTAssertEqual(huge.dayGrid(at: now, calendar: cal, maxCells: 0).cellCount, 1)
        XCTAssertEqual(huge.dayGrid(at: now, calendar: cal, maxCells: Int.max).daysPerCell, 1)
        let reversed = countdown(start: LocalDay(year: 2026, month: 11, day: 22), target: LocalDay(year: 2026, month: 10, day: 22))
        let state = reversed.dayGrid(at: now, calendar: cal)
        XCTAssertEqual(state.totalDays, 1); XCTAssertEqual(state.elapsedDays, 1)
    }
    func testGridStylePersistsWithoutChangingOtherEntries() throws {
        var library = CountdownLibrary(entries: [CountdownEntry(), CountdownEntry()])
        library.entries[0].countdown.style = .grid
        let decoded = try JSONDecoder().decode(CountdownLibrary.self, from: JSONEncoder().encode(library))
        XCTAssertEqual(decoded, library); XCTAssertTrue(decoded.isValid)
        XCTAssertEqual(decoded.entries[1].countdown.style, .ring)
        library.entries[0].timer = FocusTimer(minutes: 45)
        XCTAssertFalse(library.isValid)
    }
}
