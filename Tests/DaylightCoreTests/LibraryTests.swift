import XCTest
import CoreGraphics
@testable import DaylightCore

final class LibraryTests: XCTestCase {
    private func withFile(_ body: (URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try body(folder.appendingPathComponent("countdown.json"))
    }

    func testLegacyMigrationPreservesEveryCountdownSetting() throws {
        try withFile { url in
            var original = Countdown()
            original.title = "Cumple Fede"
            original.target = LocalDay(year: 2026, month: 11, day: 17)
            original.started = LocalDay(year: 2025, month: 11, day: 17)
            original.accent = .blue; original.allSpaces = true
            try CountdownFile.write(original, to: url)
            let originalBytes = try Data(contentsOf: url)
            let result = try CountdownLibraryFile.read(from: url)
            XCTAssertTrue(result.migrated)
            XCTAssertEqual(result.library.entries.count, 1)
            XCTAssertEqual(result.library.selected?.countdown, original)
            XCTAssertEqual(result.library.selected?.isVisible, true)
            XCTAssertEqual(try Data(contentsOf: url), originalBytes)
        }
    }

    func testWidgetsKeepIndependentDatesAndStyles() {
        var library = CountdownLibrary()
        let first = library.selectedID!
        let second = library.add()
        library.update(first) { $0.countdown.style = .number; $0.countdown.theme = .paper }
        library.update(second) {
            $0.countdown.style = .flip
            $0.countdown.target = LocalDay(year: 2030, month: 1, day: 1)
        }
        XCTAssertEqual(library.entries[0].countdown.style, .number)
        XCTAssertEqual(library.entries[0].countdown.theme, .paper)
        XCTAssertEqual(library.entries[1].countdown.style, .flip)
        XCTAssertNotEqual(library.entries[0].countdown.target, library.entries[1].countdown.target)
    }

    func testDuplicateGetsIndependentIdentityAndPlacement() {
        var library = CountdownLibrary()
        let first = library.selectedID!
        library.update(first) {
            $0.countdown.title = "Trip"
            $0.countdown.style = .flip
            $0.placement = WidgetPlacement(x: 10, y: 20, width: 360, height: 320, displayID: "external")
        }
        let second = library.duplicate(first)!
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(library.selected?.countdown.title, "Trip copy")
        XCTAssertEqual(library.selected?.countdown.style, .flip)
        XCTAssertNil(library.selected?.placement)
        library.update(second) { $0.countdown.style = .ring }
        XCTAssertEqual(library.entries[0].countdown.style, .flip)
    }

    func testDeletingSelectionKeepsOtherWidgetsAndAllowsEmptyLibrary() {
        var library = CountdownLibrary()
        let first = library.selectedID!
        let second = library.add()
        XCTAssertEqual(library.remove(second)?.id, second)
        XCTAssertEqual(library.selectedID, first)
        XCTAssertTrue(library.isValid)
        library.remove(first)
        XCTAssertNil(library.selectedID)
        XCTAssertTrue(library.entries.isEmpty)
        XCTAssertTrue(library.isValid)
        library.add()
        XCTAssertNotNil(library.selectedID)
        XCTAssertTrue(library.isValid)
    }

    func testDeletingUnselectedCountdownDoesNotSwitchSelection() {
        var library = CountdownLibrary()
        let first = library.selectedID!
        let second = library.add()
        library.remove(first)
        XCTAssertEqual(library.selectedID, second)
    }

    func testRelaunchRoundTripPreservesVisibilityAndEachDisplayPlacement() throws {
        try withFile { url in
            var library = CountdownLibrary()
            let first = library.selectedID!
            let second = library.add()
            library.update(first) {
                $0.countdown.style = .number
                $0.isVisible = false
                $0.placement = WidgetPlacement(x: 100, y: 80, width: 360, height: 320, displayID: "display-a")
            }
            library.update(second) {
                $0.countdown.style = .flip
                $0.countdown.alwaysOnTop = true
                $0.placement = WidgetPlacement(x: 400, y: 200, width: 900, height: 650, displayID: "display-b")
            }
            try CountdownLibraryFile.write(library, to: url)
            let restored = try CountdownLibraryFile.read(from: url)
            XCTAssertFalse(restored.migrated)
            XCTAssertEqual(restored.library, library)
            XCTAssertEqual(restored.library.entries.filter(\.isVisible).map(\.id), [second])
        }
    }

    func testDuplicateIDsAndMissingSelectionAreRejected() throws {
        try withFile { url in
            let entry = CountdownEntry()
            let duplicates = CountdownLibrary(entries: [entry, entry])
            XCTAssertThrowsError(try CountdownLibraryFile.write(duplicates, to: url))
            var missing = CountdownLibrary()
            missing.selectedID = UUID()
            XCTAssertThrowsError(try CountdownLibraryFile.write(missing, to: url))
        }
    }

    func testUnknownFormatDoesNotFallBackToSingleCountdown() throws {
        try withFile { url in
            var future = CountdownLibrary()
            future.version = 4
            let data = try JSONEncoder().encode(future)
            try data.write(to: url)
            XCTAssertThrowsError(try CountdownLibraryFile.read(from: url))
            XCTAssertEqual(try Data(contentsOf: url), data)
        }
    }

    func testWindowPositionFollowsDisplayAfterMonitorRearrangement() {
        let placement = WidgetPlacement(x: 100, y: 200, width: 560, height: 460, displayID: "monitor")
        let rect = placement.frame(in: CGRect(x: -1920, y: 100, width: 1920, height: 1080))
        XCTAssertEqual(rect, CGRect(x: -1820, y: 300, width: 560, height: 460))
    }

    func testWindowFitsSmallerDisplayAndCannotRestoreOffscreen() {
        let placement = WidgetPlacement(x: 1800, y: -200, width: 1900, height: 1500, displayID: "missing")
        let screen = CGRect(x: 0, y: 50, width: 1280, height: 720)
        XCTAssertEqual(placement.frame(in: screen), screen)
        let invalid = WidgetPlacement(x: .infinity, y: 0, width: 400, height: 400, displayID: "")
        XCTAssertFalse(invalid.isValid)
    }

    func testExtraSmallRestoresWithoutBeingEnlargedAndStaysOnScreen() {
        let placement = WidgetPlacement(x: 1200, y: -20, width: 260, height: 240, displayID: "monitor")
        let frame = placement.frame(in: CGRect(x: 0, y: 50, width: 1280, height: 720))
        XCTAssertEqual(frame, CGRect(x: 1020, y: 50, width: 260, height: 240))
    }

    func testExtraSmallRoundTripsForBothCountdownsAndTimers() throws {
        try withFile { url in
            var library = CountdownLibrary()
            let day = library.selectedID!
            let timer = library.addTimer(FocusTimer(minutes: 45))!
            for id in [day, timer] {
                library.update(id) {
                    $0.countdown.size = .extraSmall
                    $0.placement = WidgetPlacement(x: 20, y: 30, width: WidgetSize.extraSmall.width,
                                                   height: WidgetSize.extraSmall.height, displayID: "monitor")
                }
            }
            try CountdownLibraryFile.write(library, to: url)
            XCTAssertEqual(try CountdownLibraryFile.read(from: url).library, library)
        }
    }
}
