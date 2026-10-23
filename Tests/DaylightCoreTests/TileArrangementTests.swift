import XCTest
@testable import DaylightCore

final class TileArrangementTests: XCTestCase {
    private func items(_ count: Int, size: CGSize = CGSize(width: 260, height: 240)) -> [TileArrangement.Item] {
        (0..<count).map { _ in TileArrangement.Item(id: UUID(), size: size) }
    }
    private func assertFits(_ result: TileArrangement.Result, screens: [CGRect], file: StaticString = #filePath, line: UInt = #line) {
        for item in result.placements {
            XCTAssertTrue(screens[item.screenIndex].insetBy(dx: 16, dy: 16).contains(item.frame), file: file, line: line)
            XCTAssertGreaterThanOrEqual(item.frame.width, 260, file: file, line: line)
            XCTAssertGreaterThanOrEqual(item.frame.height, 240, file: file, line: line)
        }
        for (index, a) in result.placements.enumerated() {
            for b in result.placements.dropFirst(index + 1) where a.screenIndex == b.screenIndex {
                XCTAssertFalse(a.frame.insetBy(dx: -7.9, dy: -7.9).intersects(b.frame.insetBy(dx: -7.9, dy: -7.9)), file: file, line: line)
            }
        }
    }
    func testRowsFollowInputOrderAndFillLeftToRightFromTop() {
        let input = items(5)
        let screen = CGRect(x: -1920, y: 40, width: 1000, height: 800)
        let result = TileArrangement.arrange(input, screens: [screen])
        XCTAssertTrue(result.unplaced.isEmpty)
        XCTAssertEqual(result.placements.map(\.id), input.map(\.id))
        XCTAssertEqual(result.placements[0].frame.minX, screen.minX + 16)
        XCTAssertEqual(result.placements[0].frame.maxY, screen.maxY - 16)
        XCTAssertGreaterThan(result.placements[1].frame.minX, result.placements[0].frame.maxX)
        XCTAssertLessThan(result.placements[3].frame.maxY, result.placements[0].frame.minY)
        assertFits(result, screens: [screen])
    }
    func testLargeMixedTilesShrinkToFitPreferredScreen() {
        let input = [CGSize(width: 900, height: 650), CGSize(width: 360, height: 320), CGSize(width: 560, height: 460), CGSize(width: 260, height: 240), CGSize(width: 900, height: 650)].map { TileArrangement.Item(id: UUID(), size: $0) }
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 850), CGRect(x: 1440, y: 0, width: 1920, height: 1080)]
        let result = TileArrangement.arrange(input, screens: screens)
        XCTAssertTrue(result.unplaced.isEmpty)
        XCTAssertTrue(result.placements.allSatisfy { $0.screenIndex == 0 })
        XCTAssertLessThan(result.placements[0].frame.width, 900)
        assertFits(result, screens: screens)
    }
    func testOverflowUsesNextDisplayAndPreservesOrder() {
        let input = items(3)
        let screens = [CGRect(x: 0, y: 0, width: 600, height: 300), CGRect(x: -600, y: 0, width: 600, height: 300)]
        let result = TileArrangement.arrange(input, screens: screens)
        XCTAssertTrue(result.unplaced.isEmpty)
        XCTAssertEqual(result.placements.map(\.screenIndex), [0, 0, 1])
        XCTAssertEqual(result.placements.map(\.id), input.map(\.id))
        assertFits(result, screens: screens)
    }
    func testCapacityLimitDoesNotOverlapOrLoseEntries() {
        let input = items(5)
        let screen = CGRect(x: 0, y: 0, width: 600, height: 300)
        let result = TileArrangement.arrange(input, screens: [screen])
        XCTAssertEqual(result.placements.count, 2)
        XCTAssertEqual(result.unplaced, Array(input.dropFirst(2).map(\.id)))
        assertFits(result, screens: [screen])
        XCTAssertEqual(TileArrangement.arrange(input, screens: []).unplaced.count, 5)
        XCTAssertTrue(TileArrangement.arrange([], screens: [screen]).placements.isEmpty)
    }
    func testInPlaceArrangementKeepsEachTileOnItsCurrentDisplay() {
        let screens = [CGRect(x: -1200, y: 100, width: 1200, height: 800), CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        let input = (0..<6).map { index in
            TileArrangement.Item(id: UUID(), size: CGSize(width: 560, height: 460), screenIndex: index % 2)
        }
        let result = TileArrangement.arrangeOnCurrentScreens(input, screens: screens)
        XCTAssertTrue(result.unplaced.isEmpty)
        for placement in result.placements {
            XCTAssertEqual(placement.screenIndex, input.first { $0.id == placement.id }!.screenIndex)
        }
        for screenIndex in screens.indices {
            XCTAssertEqual(result.placements.filter { $0.screenIndex == screenIndex }.map(\.id),
                           input.filter { $0.screenIndex == screenIndex }.map(\.id))
        }
        assertFits(result, screens: screens)
    }
    func testInPlaceOverflowNeverSpillsIntoAnotherDisplay() {
        let screens = [CGRect(x: 0, y: 0, width: 600, height: 300), CGRect(x: 600, y: 0, width: 1920, height: 1080)]
        let crowded = items(5)
        let other = TileArrangement.Item(id: UUID(), size: CGSize(width: 260, height: 240), screenIndex: 1)
        let result = TileArrangement.arrangeOnCurrentScreens(crowded + [other], screens: screens)
        XCTAssertEqual(result.unplaced, crowded.dropFirst(2).map(\.id))
        XCTAssertEqual(result.placements.filter { $0.screenIndex == 1 }.map(\.id), [other.id])
        assertFits(result, screens: screens)
    }

    func testNearestDeadlineIncludesTimersAndStableOverdueOrder() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 12))!
        func entry(_ day: Int) -> CountdownEntry {
            var value = Countdown(now: now, calendar: cal)
            value.target = LocalDay(year: 2026, month: 10, day: day)
            return CountdownEntry(countdown: value)
        }
        let far = entry(30), soon = entry(23), old = entry(20), older = entry(19)
        var timer = entry(30); timer.timer = FocusTimer(minutes: 45, now: now)
        let input = [far, old, soon, timer, older]
        XCTAssertEqual(TileArrangement.nearestFirst(input, now: now, calendar: cal).map(\.id), [old.id, older.id, timer.id, soon.id, far.id])
    }
}
