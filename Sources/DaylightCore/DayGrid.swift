import Foundation

public struct DayGridSnapshot: Equatable, Sendable {
    public let totalDays: Int
    public let elapsedDays: Int
    public let daysPerCell: Int
    public let cellCount: Int
    public let currentCell: Int?

    /// A final grouped square may represent fewer days than the other squares.
    public func completion(of cell: Int) -> Double {
        guard (0..<cellCount).contains(cell) else { return 0 }
        let start = cell * daysPerCell
        let length = min(daysPerCell, totalDays - start)
        return min(1, max(0, Double(elapsedDays - start) / Double(length)))
    }
}

extension Countdown {
    public func dayGrid(at now: Date = Date(), calendar: Calendar = .autoupdatingCurrent, maxCells: Int = 600) -> DayGridSnapshot {
        let targetDay = calendar.startOfDay(for: target.date(in: calendar))
        let configuredStart = calendar.startOfDay(for: started.date(in: calendar))
        // Same-day or reversed timelines still have one meaningful day ending at the target.
        let start = configuredStart < targetDay ? configuredStart : calendar.date(byAdding: .day, value: -1, to: targetDay)!
        let today = calendar.startOfDay(for: now)
        let total = max(1, calendar.dateComponents([.day], from: start, to: targetDay).day ?? 1)
        let elapsed = min(total, max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0))
        let capacity = min(total, max(1, maxCells))
        let perCell = max(1, (total + capacity - 1) / capacity)
        let count = (total + perCell - 1) / perCell
        return DayGridSnapshot(totalDays: total, elapsedDays: elapsed, daysPerCell: perCell, cellCount: count,
                               currentCell: today >= start && today < targetDay ? elapsed / perCell : nil)
    }
}
