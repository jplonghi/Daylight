import XCTest
@testable import DaylightCore

final class WidgetDisplayTests: XCTestCase {
    private let laptop = WidgetDisplay(id: "laptop", visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 860))
    private let external = WidgetDisplay(id: "external", visibleFrame: CGRect(x: 1440, y: 0, width: 2560, height: 1400))
    private let preferred = WidgetPlacement(x: 1700, y: 600, width: 800, height: 650, displayID: "external")

    func testReconnectUsesStableIdentityAfterDisplayOrderAndOriginChange() {
        let movedExternal = WidgetDisplay(id: external.id, visibleFrame: CGRect(x: -2560, y: -300, width: 2560, height: 1400))
        let another = WidgetDisplay(id: "another", visibleFrame: external.visibleFrame)
        XCTAssertEqual(preferred.restoredFrame(on: [another, movedExternal, laptop]),
                       CGRect(x: -860, y: 300, width: 800, height: 650))
    }


    func testFallbackUsesAvailableMainDisplayAndHandlesNoDisplays() {
        let other = WidgetDisplay(id: "other", visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let frame = preferred.restoredFrame(on: [other, laptop], fallbackDisplayID: laptop.id)
        XCTAssertEqual(frame?.midX, laptop.visibleFrame.midX)
        XCTAssertEqual(frame?.midY, laptop.visibleFrame.midY)
        XCTAssertNil(preferred.restoredFrame(on: []))
    }


    func testSmallerFallbackDoesNotMutateSavedDimensions() throws {
        let small = WidgetDisplay(id: "small", visibleFrame: CGRect(x: -600, y: 30, width: 600, height: 400))
        XCTAssertEqual(preferred.restoredFrame(on: [small]), small.visibleFrame)
        XCTAssertEqual(preferred.restoredFrame(on: [external]), preferred.frame(in: external.visibleFrame))
        XCTAssertEqual(preferred.width, 800)
        XCTAssertEqual(preferred.height, 650)
    }
}
