import Foundation
import CoreGraphics

/// Tests the window order without assuming that application focus equals visibility.
public enum TileWindowVisibility {
    public struct Window: Sendable {
        public let id: Int
        public let frame: CGRect
        public let level: Int

        public init(id: Int, frame: CGRect, level: Int = 0) {
            self.id = id
            self.frame = frame
            self.level = level
        }
    }

    /// The caller supplies visible application windows, ordered front to back.
    /// Tile overlap is allowed; windows elsewhere on the desktop do not cover a tile.
    public static func areUncovered(_ tileIDs: Set<Int>, in windows: [Window]) -> Bool {
        guard !tileIDs.isEmpty else { return false }
        var found: Set<Int> = []
        var blockers: [Window] = []
        for window in windows where !window.frame.isEmpty {
            if tileIDs.contains(window.id) {
                // Raising a normal tile cannot overtake a floating panel. Such a panel
                // must not leave the toggle stuck trying to raise the tile forever.
                if blockers.contains(where: { $0.level <= window.level && $0.frame.intersects(window.frame) }) { return false }
                found.insert(window.id)
                if found == tileIDs { return true }
            } else {
                blockers.append(window)
            }
        }
        return false
    }
}
