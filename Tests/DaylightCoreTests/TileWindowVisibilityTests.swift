import XCTest
@testable import DaylightCore

final class TileWindowVisibilityTests: XCTestCase {
    private let a = TileWindowVisibility.Window(id: 1, frame: CGRect(x: -1000, y: 50, width: 360, height: 320))
    private let b = TileWindowVisibility.Window(id: 2, frame: CGRect(x: 100, y: 100, width: 360, height: 320))

    func testTilesAheadOfOtherWindowsAreUncovered() {
        let behind = TileWindowVisibility.Window(id: 3, frame: a.frame)
        XCTAssertTrue(TileWindowVisibility.areUncovered([1, 2], in: [a, b, behind]))
    }

    func testWindowCoveringAnyTileRequiresBringingTilesForward() {
        let covering = TileWindowVisibility.Window(id: 3, frame: b.frame)
        XCTAssertFalse(TileWindowVisibility.areUncovered([1, 2], in: [a, covering, b]))
    }

    func testFrontWindowElsewhereDoesNotResetTheToggle() {
        let elsewhere = TileWindowVisibility.Window(id: 3, frame: CGRect(x: 900, y: 50, width: 600, height: 500))
        XCTAssertTrue(TileWindowVisibility.areUncovered([1, 2], in: [elsewhere, a, b]))
    }

    func testOverlappingTilesDoNotCountAsObstructions() {
        let overlapping = TileWindowVisibility.Window(id: 2, frame: a.frame.offsetBy(dx: 50, dy: 50))
        XCTAssertTrue(TileWindowVisibility.areUncovered([1, 2], in: [a, overlapping]))
    }

    func testMissingOrMinimizedTileRequiresBringingTilesForward() {
        XCTAssertFalse(TileWindowVisibility.areUncovered([1, 2], in: [a]))
        XCTAssertFalse(TileWindowVisibility.areUncovered([], in: [a, b]))
        XCTAssertFalse(TileWindowVisibility.areUncovered([1], in: []))
    }

    func testFloatingPanelDoesNotKeepNormalTileToggleStuck() {
        let panel = TileWindowVisibility.Window(id: 3, frame: a.frame, level: 3)
        XCTAssertTrue(TileWindowVisibility.areUncovered([1], in: [panel, a]))
        let pinnedTile = TileWindowVisibility.Window(id: 1, frame: a.frame, level: 3)
        XCTAssertFalse(TileWindowVisibility.areUncovered([1], in: [panel, pinnedTile]))
    }
}
