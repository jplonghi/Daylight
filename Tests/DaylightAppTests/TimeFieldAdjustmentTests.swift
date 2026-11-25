import AppKit
import XCTest
@testable import Daylight

final class TimeFieldAdjustmentTests: XCTestCase {
    @MainActor
    func testScrollOnlyAdjustsTheFieldUnderThePointerAndLeavesClicksAlone() throws {
        _ = NSApplication.shared
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("Requires a Window Server session.") }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 240, height: 180),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let field = TimeFieldScrollArea.ScrollView(frame: NSRect(x: 20, y: 20, width: 84, height: 56))
        window.contentView?.addSubview(field)
        var value = "59"
        field.adjust = { value = FinishTimePart.minute.adjusting(value, by: $0) }
        let event = FieldScrollEvent()
        event.targetWindow = window
        event.point = NSPoint(x: 40, y: 40)
        XCTAssertNil(field.handleScroll(event), "Scrolling over a time field should be consumed.")
        XCTAssertEqual(value, "00")
        XCTAssertNil(field.hitTest(NSPoint(x: 30, y: 30)), "The scroll observer must not intercept editing clicks.")
        event.amount = -1
        XCTAssertNil(field.handleScroll(event))
        XCTAssertEqual(value, "59")
        event.point = NSPoint(x: 180, y: 140)
        XCTAssertTrue(field.handleScroll(event) === event)
        XCTAssertEqual(value, "59", "Scrolling elsewhere must not change this field.")
        event.point = NSPoint(x: 40, y: 40)
        event.targetWindow = nil
        XCTAssertTrue(field.handleScroll(event) === event)
        XCTAssertEqual(value, "59", "Another window's scrolling must pass through.")
        field.removeFromSuperview()
    }

    func testTimePartsWrapIndependentlyAndKeepMinutesPadded() {
        XCTAssertEqual(FinishTimePart.hour.adjusting("12", by: 1), "1")
        XCTAssertEqual(FinishTimePart.hour.adjusting("1", by: -1), "12")
        XCTAssertEqual(FinishTimePart.minute.adjusting("59", by: 1), "00")
        XCTAssertEqual(FinishTimePart.minute.adjusting("00", by: -1), "59")
        XCTAssertEqual(FinishTimePart.minute.adjusting("5", by: 1), "06")
        XCTAssertEqual(FinishTimePart.minute.adjusting("59", by: 3), "02")
    }

    func testAdjustingInvalidInputRecoversToAValidTime() {
        XCTAssertEqual(FinishTimePart.hour.adjusting("", by: 1), "1")
        XCTAssertEqual(FinishTimePart.hour.adjusting("99", by: -1), "1")
        XCTAssertEqual(FinishTimePart.minute.adjusting("abc", by: -1), "00")
        XCTAssertEqual(FinishTimePart.minute.adjusting(" 09 ", by: 1), "10")
    }

    func testWheelMovesOneUnitPerEventInBothDirections() {
        var scroll = TimeFieldScrollSteps()
        XCTAssertEqual(scroll.consume(delta: 3, precise: false, momentum: false, newGesture: false, timestamp: 1), 1)
        XCTAssertEqual(scroll.consume(delta: -3, precise: false, momentum: false, newGesture: false, timestamp: 1.1), -1)
        XCTAssertEqual(scroll.consume(delta: 0, precise: false, momentum: false, newGesture: false, timestamp: 1.2), 0)
    }

    func testTrackpadAccumulatesSmallMovementsAndIgnoresMomentum() {
        var scroll = TimeFieldScrollSteps()
        XCTAssertEqual(scroll.consume(delta: 8, precise: true, momentum: false, newGesture: true, timestamp: 1), 0)
        XCTAssertEqual(scroll.consume(delta: 15, precise: true, momentum: false, newGesture: false, timestamp: 1.1), 1)
        XCTAssertEqual(scroll.consume(delta: 37, precise: true, momentum: false, newGesture: false, timestamp: 1.2), 2)
        XCTAssertEqual(scroll.consume(delta: 100, precise: true, momentum: true, newGesture: false, timestamp: 1.3), 0)
    }

    func testReversingOrStartingAnotherGestureDiscardsPartialMovement() {
        var scroll = TimeFieldScrollSteps()
        XCTAssertEqual(scroll.consume(delta: 19, precise: true, momentum: false, newGesture: true, timestamp: 1), 0)
        XCTAssertEqual(scroll.consume(delta: -20, precise: true, momentum: false, newGesture: false, timestamp: 1.1), -1)
        XCTAssertEqual(scroll.consume(delta: 19, precise: true, momentum: false, newGesture: false, timestamp: 1.2), 0)
        XCTAssertEqual(scroll.consume(delta: 1, precise: true, momentum: false, newGesture: true, timestamp: 1.3), 0)
        XCTAssertEqual(scroll.consume(delta: 19, precise: true, momentum: false, newGesture: false, timestamp: 2), 0)
    }
}

private final class FieldScrollEvent: NSEvent {
    var targetWindow: NSWindow?
    var point = NSPoint.zero
    var amount: CGFloat = 1
    override var window: NSWindow? { targetWindow }
    override var locationInWindow: NSPoint { point }
    override var scrollingDeltaY: CGFloat { amount }
    override var hasPreciseScrollingDeltas: Bool { false }
    override var momentumPhase: NSEvent.Phase { [] }
    override var phase: NSEvent.Phase { [] }
    override var timestamp: TimeInterval { 1 }
}
