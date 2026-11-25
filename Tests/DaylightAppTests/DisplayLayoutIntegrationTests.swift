import AppKit
import XCTest
import DaylightCore
@testable import Daylight

final class DisplayLayoutIntegrationTests: XCTestCase {
    /// Exercises the actual controller, NSWindow delegates and on-disk store. The display
    /// source simulates docking without changing the host's physical display configuration.
    @MainActor
    func testNativeWindowEventsPreserveLaptopAndDockedProfiles() async throws {
        _ = NSApplication.shared
        let physicalScreens = NSScreen.screens
        guard physicalScreens.count >= 2 else {
            throw XCTSkip("Requires a Window Server session with at least two connected displays.")
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("daylight-layout-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let laptop = WidgetDisplay(id: "test-laptop", visibleFrame: physicalScreens[1].visibleFrame)
        let external = WidgetDisplay(id: "test-external", visibleFrame: physicalScreens[0].visibleFrame)
        var connected = [external, laptop]
        let store = CountdownStore(dataDirectory: folder)
        let controller = AppController(store: store, displaySource: { connected })
        defer { controller.hideAllWidgets() }
        let id = try XCTUnwrap(store.selectedID)
        controller.refreshDisplays()
        try await Task.sleep(for: .milliseconds(1250))
        controller.showAllWidgets()
        let window = try XCTUnwrap(controller.widgetWindows[id] as? TileWindow)

        func userMove(to frame: CGRect) {
            window.beginUserMove?()
            window.setFrame(frame, display: false)
            controller.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: window))
        }

        let desktopFrame = CGRect(x: external.visibleFrame.minX + 180, y: external.visibleFrame.minY + 120, width: 360, height: 320)
        userMove(to: desktopFrame)
        // Disconnect before the movement debounce completes.
        controller.beginDisplayReconfiguration()
        connected = [laptop]
        let portableFrame = CGRect(x: laptop.visibleFrame.minX + 110, y: laptop.visibleFrame.minY + 150, width: 260, height: 240)
        window.setFrame(portableFrame, display: false)
        controller.refreshDisplays()
        try await Task.sleep(for: .milliseconds(1250))
        userMove(to: portableFrame)
        try await Task.sleep(for: .milliseconds(450))

        let dockKey = DisplaySetup(displays: [external, laptop]).key
        let laptopKey = DisplaySetup(displays: [laptop]).key
        XCTAssertEqual(store.entry(id)?.displayPlacements?[dockKey], WidgetPlacement(frame: desktopFrame, on: external))
        XCTAssertEqual(store.entry(id)?.displayPlacements?[laptopKey], WidgetPlacement(frame: portableFrame, on: laptop))

        controller.beginDisplayReconfiguration()
        connected = [external, laptop]
        controller.refreshDisplays()
        try await Task.sleep(for: .milliseconds(1250))
        XCTAssertEqual(window.frame, desktopFrame)

        // A late automatic move after the reconnect must restore, not save, the laptop frame.
        window.setFrame(portableFrame, display: false)
        controller.windowDidMove(Notification(name: NSWindow.didMoveNotification, object: window))
        try await Task.sleep(for: .milliseconds(1250))
        XCTAssertEqual(window.frame, desktopFrame)
        XCTAssertEqual(store.entry(id)?.displayPlacements?[dockKey], WidgetPlacement(frame: desktopFrame, on: external))

        controller.beginDisplayReconfiguration()
        connected = [laptop]
        controller.refreshDisplays()
        try await Task.sleep(for: .milliseconds(1250))
        XCTAssertEqual(window.frame, portableFrame)
        store.saveNow()
        let reloaded = try CountdownLibraryFile.read(from: folder.appendingPathComponent("countdown.json")).library
        XCTAssertEqual(reloaded.entries[0].displayPlacements, store.entry(id)?.displayPlacements)
        XCTAssertEqual(reloaded.entries[0].displayPlacements?.count, 2)
    }
}
