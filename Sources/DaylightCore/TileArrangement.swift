import Foundation
import CoreGraphics

/// Ordered shelf packing in screen coordinates.
public enum TileArrangement {
    public struct Item: Sendable {
        public let id: UUID
        public let size: CGSize
        public let screenIndex: Int
        public init(id: UUID, size: CGSize, screenIndex: Int = 0) {
            self.id = id; self.size = size; self.screenIndex = screenIndex
        }
    }
    public struct Placement: Sendable {
        public let id: UUID
        public let screenIndex: Int
        public let frame: CGRect
    }
    public struct Result: Sendable {
        public let placements: [Placement]
        public let unplaced: [UUID]
    }

    public static func nearestFirst(_ entries: [CountdownEntry], now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [CountdownEntry] {
        entries.enumerated().sorted {
            let a = max(now, $0.element.timer?.endsAt ?? $0.element.countdown.target.date(in: calendar))
            let b = max(now, $1.element.timer?.endsAt ?? $1.element.countdown.target.date(in: calendar))
            return a == b ? $0.offset < $1.offset : a < b
        }.map(\.element)
    }

    /// Fit each display independently without moving overflow to another display.
    public static func arrangeOnCurrentScreens(_ items: [Item], screens: [CGRect], gap: CGFloat = 16) -> Result {
        var placements: [Placement] = []
        var unplaced = items.filter { !screens.indices.contains($0.screenIndex) }.map(\.id)
        for (index, screen) in screens.enumerated() {
            let group = items.filter { $0.screenIndex == index }
            let result = arrange(group, screens: [screen], gap: gap)
            placements += result.placements.map { Placement(id: $0.id, screenIndex: index, frame: $0.frame) }
            unplaced += result.unplaced
        }
        return Result(placements: placements, unplaced: unplaced)
    }

    public static func arrange(_ items: [Item], screens: [CGRect], gap: CGFloat = 16) -> Result {
        guard !items.isEmpty else { return Result(placements: [], unplaced: []) }
        guard !screens.isEmpty else { return Result(placements: [], unplaced: items.map(\.id)) }
        // Prefer fitting everything on the chosen screen before spilling to other screens.
        for count in [1, screens.count] {
            for step in stride(from: 100, through: 5, by: -1) {
                let result = pack(items, screens: Array(screens.prefix(count)), scale: CGFloat(step) / 100, gap: gap)
                if result.unplaced.isEmpty { return result }
            }
        }
        return pack(items, screens: screens, scale: 0.05, gap: gap)
    }

    private static func pack(_ items: [Item], screens: [CGRect], scale: CGFloat, gap: CGFloat) -> Result {
        var placements: [Placement] = []
        var index = 0
        for (screenIndex, screen) in screens.enumerated() {
            let area = screen.insetBy(dx: gap, dy: gap)
            var x = area.minX, top = area.maxY, rowHeight: CGFloat = 0
            while index < items.count {
                let item = items[index]
                let factor = max(scale, max(260 / item.size.width, 240 / item.size.height))
                let size = CGSize(width: ceil(item.size.width * factor), height: ceil(item.size.height * factor))
                if size.width > area.width || size.height > area.height { break }
                if x + size.width > area.maxX {
                    x = area.minX; top -= rowHeight + gap; rowHeight = 0
                }
                guard top - size.height >= area.minY else { break }
                placements.append(Placement(id: item.id, screenIndex: screenIndex,
                    frame: CGRect(x: x, y: top - size.height, width: size.width, height: size.height)))
                x += size.width + gap; rowHeight = max(rowHeight, size.height)
                index += 1
            }
        }
        return Result(placements: placements, unplaced: items.dropFirst(index).map(\.id))
    }
}
