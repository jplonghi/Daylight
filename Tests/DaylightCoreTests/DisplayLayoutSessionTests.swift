import XCTest
@testable import DaylightCore

final class DisplayLayoutSessionTests: XCTestCase {
    private let laptop = WidgetDisplay(id: "builtin", visibleFrame: CGRect(x: 0, y: 40, width: 1512, height: 910))
    private let mi = WidgetDisplay(id: "mi", visibleFrame: CGRect(x: 0, y: 77, width: 2560, height: 1333))
    private let hpLeft = WidgetDisplay(id: "hp-left", visibleFrame: CGRect(x: -1920, y: 476, width: 1920, height: 1080))
    private let hpRight = WidgetDisplay(id: "hp-right", visibleFrame: CGRect(x: 2560, y: 500, width: 1920, height: 1080))
    private var docked: [WidgetDisplay] {
        [mi, WidgetDisplay(id: laptop.id, visibleFrame: CGRect(x: -1512, y: -553, width: 1512, height: 950)), hpLeft, hpRight]
    }

    private func placement(on display: WidgetDisplay, x: Double = 120, y: Double = 100, width: Double = 360, height: Double = 320) -> WidgetPlacement {
        WidgetPlacement(x: x, y: y, width: width, height: height, displayID: display.id)
    }

    func testLaptopAndFourScreenArrangementsSurviveRepeatedDockCycles() throws {
        var library = CountdownLibrary(entries: (0..<4).map { _ in CountdownEntry() })
        var session = DisplayLayoutSession()
        session.activate(docked, in: &library)
        let dockPlacements = docked.enumerated().map { placement(on: $0.element, x: Double($0.offset * 80 + 50)) }
        for (entry, saved) in zip(library.entries, dockPlacements) {
            XCTAssertTrue(session.recordEdit(saved, for: entry.id, currentDisplays: docked))
        }
        // Disconnect before the deferred save fires: the captured dock placements must survive.
        session.beginReconfiguration(in: &library)
        session.activate([laptop], in: &library)
        let laptopPlacements = library.entries.indices.map { placement(on: laptop, x: Double($0 * 300), width: 260, height: 240) }
        for (entry, saved) in zip(library.entries, laptopPlacements) {
            session.recordEdit(saved, for: entry.id, currentDisplays: [laptop])
        }
        session.flushEdits(in: &library)
        for _ in 0..<3 {
            session.beginReconfiguration(in: &library)
            session.activate(docked, in: &library)
            XCTAssertEqual(library.entries.compactMap { session.placement(for: $0) }, dockPlacements)
            session.beginReconfiguration(in: &library)
            session.activate([laptop], in: &library)
            XCTAssertEqual(library.entries.compactMap { session.placement(for: $0) }, laptopPlacements)
        }
        XCTAssertTrue(library.entries.allSatisfy { $0.displayPlacements?.count == 2 })
    }

    func testDifferentOneAndTwoExternalMonitorSetsHaveSeparateLayouts() throws {
        var library = CountdownLibrary()
        var session = DisplayLayoutSession()
        let id = try XCTUnwrap(library.selectedID)
        let setups = [[laptop], [mi, laptop], [hpLeft, laptop], [mi, laptop, hpRight], docked]
        var expected: [WidgetPlacement] = []
        for (index, screens) in setups.enumerated() {
            session.beginReconfiguration(in: &library)
            session.activate(screens, in: &library)
            let saved = placement(on: screens[0], x: Double(100 + index * 50))
            session.recordEdit(saved, for: id, currentDisplays: screens)
            session.flushEdits(in: &library)
            expected.append(saved)
        }
        for (screens, saved) in zip(setups, expected) {
            session.activate(screens, in: &library)
            XCTAssertEqual(session.placement(for: library.entries[0]), saved)
        }
        XCTAssertEqual(library.entries[0].displayPlacements?.count, setups.count)
    }

    func testStagedDockArrivalDoesNotOverwriteAnyRememberedSetup() throws {
        var library = CountdownLibrary()
        let id = try XCTUnwrap(library.selectedID)
        var session = DisplayLayoutSession()
        session.activate(docked, in: &library)
        let preferred = placement(on: hpRight, x: 700, y: 500)
        session.recordEdit(preferred, for: id, currentDisplays: docked)
        session.beginReconfiguration(in: &library)
        session.activate([laptop], in: &library)
        let portable = placement(on: laptop, x: 90)
        session.recordEdit(portable, for: id, currentDisplays: [laptop])
        session.beginReconfiguration(in: &library)
        for screens in [[laptop, mi], [mi, laptop, hpLeft], docked] {
            // Window Server's temporary frame must never be accepted during reconfiguration.
            XCTAssertFalse(session.recordEdit(portable, for: id, currentDisplays: screens))
            session.activate(screens, in: &library)
            session.beginReconfiguration(in: &library)
        }
        session.activate(docked, in: &library)
        XCTAssertEqual(session.placement(for: library.entries[0]), preferred)
        session.activate([laptop], in: &library)
        XCTAssertEqual(session.placement(for: library.entries[0]), portable)
    }

    func testMainDisplayOrderAndResolutionChangesReuseExistingProfile() throws {
        var library = CountdownLibrary()
        var session = DisplayLayoutSession()
        session.activate(docked, in: &library)
        let saved = placement(on: hpRight, x: 1400, y: 700, width: 500, height: 360)
        session.recordEdit(saved, for: library.entries[0].id, currentDisplays: docked)
        session.beginReconfiguration(in: &library)
        let rearranged = [laptop, WidgetDisplay(id: hpRight.id, visibleFrame: CGRect(x: -1280, y: -200, width: 1280, height: 720)), mi, hpLeft]
        XCTAssertEqual(DisplaySetup(displays: docked), DisplaySetup(displays: rearranged))
        session.activate(rearranged, in: &library)
        let restored = try XCTUnwrap(session.placement(for: library.entries[0]))
        XCTAssertEqual(restored, saved)
        XCTAssertTrue(rearranged[1].visibleFrame.contains(try XCTUnwrap(restored.restoredFrame(on: rearranged))))
        session.activate(docked, in: &library)
        XCTAssertEqual(session.placement(for: library.entries[0]), saved)
        XCTAssertEqual(library.entries[0].displayPlacements?.count, 1)
    }

    func testDisplayChangeBeforeNotificationCannotRecordFrameIntoOldSetup() {
        var library = CountdownLibrary()
        var session = DisplayLayoutSession()
        session.activate(docked, in: &library)
        XCTAssertFalse(session.recordEdit(placement(on: laptop), for: library.entries[0].id, currentDisplays: [laptop]))
        var moved = docked
        moved[0] = WidgetDisplay(id: mi.id, visibleFrame: CGRect(x: 100, y: 100, width: 1920, height: 1080))
        XCTAssertFalse(session.recordEdit(placement(on: mi), for: library.entries[0].id, currentDisplays: moved))
    }

    func testTransientZeroDisplaysDoesNotCreateOrEraseLayouts() {
        var library = CountdownLibrary()
        var session = DisplayLayoutSession()
        session.activate(docked, in: &library)
        let saved = library
        session.beginReconfiguration(in: &library)
        XCTAssertFalse(session.activate([], in: &library))
        XCTAssertTrue(session.isReconfiguring)
        XCTAssertEqual(library, saved)
        XCTAssertFalse(session.recordEdit(placement(on: laptop), for: library.entries[0].id, currentDisplays: []))
    }

    func testQuitRelaunchOnLaptopAndThenReconnectRestoresBothLayouts() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("countdown.json")
        var library = CountdownLibrary()
        let id = library.entries[0].id
        var session = DisplayLayoutSession()
        session.activate(docked, in: &library)
        let desktop = placement(on: hpLeft, x: 600)
        session.recordEdit(desktop, for: id, currentDisplays: docked)
        session.beginReconfiguration(in: &library)
        session.activate([laptop], in: &library)
        let portable = placement(on: laptop, x: 300, width: 260, height: 240)
        session.recordEdit(portable, for: id, currentDisplays: [laptop])
        session.flushEdits(in: &library)
        try CountdownLibraryFile.write(library, to: url)
        library = try CountdownLibraryFile.read(from: url).library
        var relaunched = DisplayLayoutSession()
        relaunched.activate([laptop], in: &library)
        XCTAssertEqual(relaunched.placement(for: library.entries[0]), portable)
        relaunched.activate(docked, in: &library)
        XCTAssertEqual(relaunched.placement(for: library.entries[0]), desktop)
        XCTAssertTrue(library.isValid)
    }

    func testHiddenTilesKeepIndependentSizesAndVisibilityAcrossSetups() {
        var library = CountdownLibrary(entries: [CountdownEntry(isVisible: false)])
        var session = DisplayLayoutSession()
        session.activate(docked, in: &library)
        let desktop = placement(on: mi, width: 900, height: 650)
        session.recordEdit(desktop, for: library.entries[0].id, currentDisplays: docked)
        session.beginReconfiguration(in: &library)
        session.activate([laptop], in: &library)
        let portable = placement(on: laptop, width: 260, height: 240)
        session.recordEdit(portable, for: library.entries[0].id, currentDisplays: [laptop])
        session.flushEdits(in: &library)
        session.activate(docked, in: &library)
        XCTAssertEqual(session.placement(for: library.entries[0]), desktop)
        XCTAssertFalse(library.entries[0].isVisible)
        session.activate([laptop], in: &library)
        XCTAssertEqual(session.placement(for: library.entries[0]), portable)
    }

    func testNewAndDeletedTilesDoNotCorruptExistingLayouts() {
        var library = CountdownLibrary()
        var session = DisplayLayoutSession()
        session.activate(docked, in: &library)
        let first = library.entries[0]
        let added = library.add()
        session.ensurePlacements(in: &library)
        XCTAssertEqual(library.entries[0], first)
        XCTAssertNotNil(library.entries[1].displayPlacements?[session.setup.key])
        session.recordEdit(placement(on: hpRight), for: added, currentDisplays: docked)
        library.remove(added)
        session.flushEdits(in: &library)
        XCTAssertEqual(library.entries, [first])
        session.activate([laptop], in: &library)
        session.activate(docked, in: &library)
        XCTAssertEqual(library.entries.count, 1)
        XCTAssertEqual(session.placement(for: library.entries[0]), first.displayPlacements?[session.setup.key])
    }

    func testVersionThreeMigrationPreservesDataAndSeedsOnlyCurrentSetup() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("countdown.json")
        let saved = placement(on: hpRight, x: 500)
        var old = CountdownLibrary(entries: [CountdownEntry(placement: saved)])
        old.version = 3
        let data = try JSONEncoder().encode(old)
        try data.write(to: url)
        let loaded = try CountdownLibraryFile.read(from: url)
        XCTAssertTrue(loaded.migrated)
        XCTAssertEqual(loaded.library.version, 4)
        XCTAssertEqual(loaded.library.entries, old.entries)
        XCTAssertEqual(try Data(contentsOf: url), data)
        var library = loaded.library
        var session = DisplayLayoutSession()
        session.activate([laptop], in: &library)
        XCTAssertEqual(library.entries[0].placement, saved)
        XCTAssertEqual(session.placement(for: library.entries[0])?.displayID, laptop.id)
        session.activate(docked, in: &library)
        XCTAssertEqual(session.placement(for: library.entries[0]), saved)
    }

    func testInvalidSavedProfileIsRejected() throws {
        var library = CountdownLibrary()
        library.entries[0].displayPlacements = ["bad": WidgetPlacement(x: 0, y: 0, width: -1, height: 320, displayID: mi.id)]
        XCTAssertFalse(library.isValid)
    }
}
