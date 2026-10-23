import XCTest
@testable import DaylightCore

final class FocusTimerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_792_606_200)

    func testFortyFiveMinutesDrainsFromFullToEmpty() {
        let timer = FocusTimer(minutes: 45, now: now)
        XCTAssertEqual(timer.snapshot(at: now).clock, "45:00")
        XCTAssertEqual(timer.snapshot(at: now).fraction, 1)
        let half = timer.snapshot(at: now.addingTimeInterval(1350))
        XCTAssertEqual(half.clock, "22:30")
        XCTAssertEqual(half.fraction, 0.5, accuracy: 0.0001)
        let finished = timer.snapshot(at: timer.endsAt)
        XCTAssertTrue(finished.isFinished)
        XCTAssertEqual(finished.clock, "00:00")
        XCTAssertEqual(finished.fraction, 0)
    }

    func testFractionsOfASecondDoNotFinishEarly() {
        let timer = FocusTimer(minutes: 1, now: now)
        let lastSecond = timer.snapshot(at: timer.endsAt.addingTimeInterval(-0.01))
        XCTAssertEqual(lastSecond.seconds, 1)
        XCTAssertFalse(lastSecond.isFinished)
        XCTAssertEqual(timer.snapshot(at: timer.endsAt.addingTimeInterval(20)).seconds, 0)
    }

    func testLongTimerShowsHoursAndDoesNotExceedFullRing() {
        let timer = FocusTimer(minutes: 90, now: now)
        XCTAssertEqual(timer.snapshot(at: now).clock, "1:30:00")
        XCTAssertEqual(timer.snapshot(at: now.addingTimeInterval(-5)).fraction, 1)
    }

    private func calendar() -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Costa_Rica")!
        return value
    }

    func testExactTimeMeans235PMToday() {
        let cal = calendar()
        let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 13))!
        let clock = cal.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: 14, minute: 35))!
        let timer = FocusTimer.finishingToday(at: clock, now: start, calendar: cal)!
        XCTAssertEqual(timer.endsAt, cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 14, minute: 35)))
        XCTAssertEqual(timer.snapshot(at: start).clock, "1:35:00")
    }

    func testPastAndCurrentClockMinutesAreRejected() {
        let cal = calendar()
        let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 14, minute: 35, second: 30))!
        XCTAssertNil(FocusTimer.finishingToday(at: start, now: start, calendar: cal))
        XCTAssertNil(FocusTimer.finishingToday(at: start.addingTimeInterval(-3600), now: start, calendar: cal))
    }

    func testPastMidnightIsNotSilentlyScheduledForTomorrow() {
        let cal = calendar()
        let start = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 23, minute: 50))!
        let clock = cal.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 0, minute: 5))!
        XCTAssertNil(FocusTimer.finishingToday(at: clock, now: start, calendar: cal))
    }

    func testInvalidDurationsCannotEnterLibrary() {
        var library = CountdownLibrary(entries: [])
        XCTAssertNil(library.addTimer(FocusTimer(minutes: 0, now: now)))
        XCTAssertNil(library.addTimer(FocusTimer(minutes: -1, now: now)))
        XCTAssertFalse(FocusTimer(startedAt: now, endsAt: Date(timeIntervalSinceReferenceDate: .infinity)).isValid)
        XCTAssertTrue(library.entries.isEmpty)
    }

    func testTimerCanOnlyUseRingAndCannotBeDuplicated() {
        var library = CountdownLibrary(entries: [])
        let id = library.addTimer(FocusTimer(minutes: 25, now: now), title: "Write")!
        XCTAssertEqual(library.selected?.countdown.style, .ring)
        XCTAssertNil(library.duplicate(id))
        library.update(id) { $0.countdown.style = .flip }
        XCTAssertFalse(library.isValid)
    }

    func testAcknowledgmentOnlyRemovesFinishedTimer() {
        var library = CountdownLibrary()
        let day = library.selectedID!
        let id = library.addTimer(FocusTimer(minutes: 1, now: now))!
        XCTAssertFalse(library.acknowledgeTimer(day, at: now.addingTimeInterval(120)))
        XCTAssertFalse(library.acknowledgeTimer(id, at: now.addingTimeInterval(59)))
        XCTAssertTrue(library.acknowledgeTimer(id, at: now.addingTimeInterval(60)))
        XCTAssertEqual(library.entries.map(\.id), [day])
        XCTAssertFalse(library.acknowledgeTimer(id, at: now.addingTimeInterval(120)))
    }

    func testAcknowledgingOneExpiredTimerKeepsTheOther() {
        var library = CountdownLibrary(entries: [])
        let first = library.addTimer(FocusTimer(minutes: 1, now: now))!
        let second = library.addTimer(FocusTimer(minutes: 2, now: now))!
        XCTAssertTrue(library.acknowledgeTimer(first, at: now.addingTimeInterval(200)))
        XCTAssertEqual(library.entries.map(\.id), [second])
        XCTAssertTrue(library.entries[0].timer!.snapshot(at: now.addingTimeInterval(200)).isFinished)
    }

    func testRelaunchRetainsExactDeadlineAndExpiredTimerUntilAcknowledged() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("countdown.json")
        var library = CountdownLibrary()
        let timer = FocusTimer(minutes: 45, now: now)
        let id = library.addTimer(timer, title: "Read")!
        try CountdownLibraryFile.write(library, to: url)
        var restored = try CountdownLibraryFile.read(from: url).library
        XCTAssertEqual(library, restored)
        XCTAssertEqual(restored.selected?.timer?.endsAt, timer.endsAt)
        XCTAssertTrue(restored.selected!.timer!.snapshot(at: now.addingTimeInterval(4000)).isFinished)
        XCTAssertEqual(restored.entries.count, 2)
        XCTAssertTrue(restored.acknowledgeTimer(id, at: now.addingTimeInterval(4000)))
        try CountdownLibraryFile.write(restored, to: url)
        XCTAssertEqual(try CountdownLibraryFile.read(from: url).library.entries.count, 1)
    }

    func testVersionTwoMigratesWithoutChangingAnyExistingEntry() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("countdown.json")
        var old = CountdownLibrary()
        old.add(); old.entries[0].isVisible = false
        old.version = 2
        let data = try JSONEncoder().encode(old)
        try data.write(to: url)
        let loaded = try CountdownLibraryFile.read(from: url)
        XCTAssertTrue(loaded.migrated)
        XCTAssertEqual(loaded.library.version, 3)
        XCTAssertEqual(loaded.library.entries, old.entries)
        XCTAssertEqual(loaded.library.selectedID, old.selectedID)
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
}
