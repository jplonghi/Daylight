import AppKit
import XCTest
import DaylightCore
@testable import Daylight

final class StatusItemInteractionTests: XCTestCase {
    @MainActor
    func testRightClickTogglesImmediatelyAndLeftClickShowsMenu() async throws {
        let app = NSApplication.shared
        guard let screen = NSScreen.screens.first else {
            throw XCTSkip("Requires a Window Server session.")
        }
        let previousPolicy = app.activationPolicy()
        app.setActivationPolicy(.accessory)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("daylight-status-test-\(UUID())")
        let display = WidgetDisplay(id: "test-display", visibleFrame: screen.visibleFrame)
        var library = CountdownLibrary(entries: (0..<3).map { index in
            CountdownEntry(isVisible: index == 0,
                           placement: WidgetPlacement(x: Double(50 + index * 280), y: 100,
                                                      width: 260, height: 240, displayID: display.id))
        })
        library.entries[2].timer = FocusTimer(minutes: 45)
        library.entries[2].countdown.style = .ring
        library.entries[1].countdown.alwaysOnTop = true
        try CountdownLibraryFile.write(library, to: folder.appendingPathComponent("countdown.json"))
        let store = CountdownStore(dataDirectory: folder)
        let controller = AppController(store: store, displaySource: { [display] })
        func click(_ type: NSEvent.EventType = .rightMouseUp, flags: NSEvent.ModifierFlags = [], count: Int = 1) throws {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: flags,
                                                       timestamp: ProcessInfo.processInfo.systemUptime,
                                                       windowNumber: 0, context: nil, eventNumber: 0,
                                                       clickCount: count, pressure: 0))
            controller.handleStatusItemClick(event) { XCTFail("A secondary click should toggle tiles, not open the menu.") }
        }
        var menuOpenCount = 0
        for count in [1, 2] {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [],
                                                       timestamp: 0, windowNumber: 0, context: nil,
                                                       eventNumber: 0, clickCount: count, pressure: 0))
            controller.handleStatusItemClick(event) { menuOpenCount += 1 }
        }
        controller.handleStatusItemClick(nil) { menuOpenCount += 1 } // Keyboard/accessibility activation.
        XCTAssertEqual(menuOpenCount, 3)
        XCTAssertTrue(controller.widgetWindows.isEmpty, "Opening the menu must not change tile visibility.")
        XCTAssertFalse(store.entries[1].isVisible)
        XCTAssertNil(controller.editorWindow)
        let cover = NSWindow(contentRect: screen.visibleFrame, styleMask: [.titled], backing: .buffered, defer: false)
        cover.isReleasedWhenClosed = false
        defer {
            cover.close()
            controller.hideAllWidgets()
            controller.editorWindow?.close()
            store.saveNow()
            app.setActivationPolicy(previousPolicy)
            try? FileManager.default.removeItem(at: folder)
        }
        controller.refreshDisplays()
        try await Task.sleep(for: .milliseconds(1250))
        controller.showWidget(library.entries[0].id)
        let initialWindow = try XCTUnwrap(controller.widgetWindows[library.entries[0].id])
        let initialFrame = initialWindow.frame
        let initialLevel = initialWindow.level
        let savedLayouts = store.entries.map(\.displayPlacements)
        cover.orderFrontRegardless()

        func singleClick() async throws {
            try click()
            // No wait here: hidden tiles must already exist when the handler returns.
            XCTAssertEqual(controller.widgetWindows.count, 3)
            XCTAssertTrue(store.entries.allSatisfy(\.isVisible))
            try await Task.sleep(for: .milliseconds(100)) // Allow Window Server ordering to settle.
        }

        let previousKeyWindow = app.keyWindow
        let wasActive = app.isActive
        try await singleClick()
        XCTAssertTrue(app.keyWindow === previousKeyWindow)
        XCTAssertEqual(app.isActive, wasActive, "Showing tiles should not activate the app.")
        XCTAssertNil(controller.editorWindow, "A single click must not open the editor.")
        XCTAssertEqual(controller.widgetWindows.count, 3)
        XCTAssertTrue(store.entries.allSatisfy(\.isVisible))
        XCTAssertTrue(controller.widgetWindows.values.allSatisfy(\.isVisible))
        XCTAssertEqual(initialWindow.frame, initialFrame)
        XCTAssertEqual(initialWindow.level, initialLevel, "Raising tiles must not enable always-on-top.")
        XCTAssertEqual(store.entries.map(\.displayPlacements), savedLayouts)
        let ordered = app.orderedWindows
        let coverIndex = try XCTUnwrap(ordered.firstIndex { $0 === cover })
        for window in controller.widgetWindows.values {
            XCTAssertLessThan(try XCTUnwrap(ordered.firstIndex { $0 === window }), coverIndex)
        }

        // A second single click sends even pinned tiles back without hiding them.
        try click(.leftMouseUp, flags: .control)
        XCTAssertEqual(controller.widgetWindows[library.entries[1].id]?.level, .normal,
                       "Sending tiles back must finish before the handler returns.")
        try await Task.sleep(for: .milliseconds(100))
        let lowered = app.orderedWindows
        let loweredCoverIndex = try XCTUnwrap(lowered.firstIndex { $0 === cover })
        for window in controller.widgetWindows.values {
            XCTAssertGreaterThan(try XCTUnwrap(lowered.firstIndex { $0 === window }), loweredCoverIndex)
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(window.level, .normal)
        }
        XCTAssertTrue(store.entries.allSatisfy(\.isVisible))
        XCTAssertTrue(store.entries[1].countdown.alwaysOnTop)
        XCTAssertEqual(store.entries.map(\.displayPlacements), savedLayouts)

        // A third single click raises them again and restores the pin preference.
        try await singleClick()
        let raisedAgain = app.orderedWindows
        let raisedCoverIndex = try XCTUnwrap(raisedAgain.firstIndex { $0 === cover })
        for window in controller.widgetWindows.values {
            XCTAssertLessThan(try XCTUnwrap(raisedAgain.firstIndex { $0 === window }), raisedCoverIndex)
        }
        XCTAssertEqual(controller.widgetWindows[library.entries[1].id]?.level, .floating)

        // Repeated right-clicks keep toggling even when macOS reports a multi-click.
        try click(count: 2)
        XCTAssertEqual(controller.widgetWindows[library.entries[1].id]?.level, .normal)
        XCTAssertNil(controller.editorWindow)
        // The menu's Manage countdowns action opens the editor.
        controller.showEditor()
        let editor = try XCTUnwrap(controller.editorWindow)
        XCTAssertTrue(editor.isVisible)
        XCTAssertEqual(controller.widgetWindows[library.entries[1].id]?.level, .normal,
                       "Opening the editor must not toggle tiles.")

        // Raise tiles immediately after showing the editor: an unnecessary Dock
        // restore used to bring the editor back above them on a later run-loop turn.
        let editorKeyWindow = app.keyWindow
        try await singleClick()
        XCTAssertTrue(app.keyWindow === editorKeyWindow, "Raising tiles must preserve keyboard focus in the editor.")
        let afterSingleClick = app.orderedWindows
        let editorIndex = try XCTUnwrap(afterSingleClick.firstIndex { $0 === editor })
        for window in controller.widgetWindows.values {
            XCTAssertLessThan(try XCTUnwrap(afterSingleClick.firstIndex { $0 === window }), editorIndex)
        }
        XCTAssertEqual(initialWindow.frame, initialFrame)
        XCTAssertEqual(store.entries.map(\.displayPlacements), savedLayouts)

        // Actual covering windows, not activation callbacks, determine whether tiles need raising.
        cover.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(100)) // Publish the covering window's order to Window Server.
        try await singleClick()
        let afterReturning = app.orderedWindows
        XCTAssertLessThan(try XCTUnwrap(afterReturning.firstIndex { $0 === initialWindow }),
                          try XCTUnwrap(afterReturning.firstIndex { $0 === cover }))
    }
}
