import Foundation

/// Absolute instants keep timers accurate through sleep, relaunch and time-zone changes.
public struct FocusTimer: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var endsAt: Date

    public init(startedAt: Date, endsAt: Date) {
        self.startedAt = startedAt; self.endsAt = endsAt
    }

    public init(minutes: Int, now: Date = Date()) {
        self.init(startedAt: now, endsAt: now.addingTimeInterval(Double(minutes) * 60))
    }

    public var isValid: Bool {
        startedAt.timeIntervalSinceReferenceDate.isFinite
            && endsAt.timeIntervalSinceReferenceDate.isFinite && endsAt > startedAt
    }

    public func snapshot(at now: Date = Date()) -> FocusTimerSnapshot {
        let remaining = max(0, endsAt.timeIntervalSince(now))
        return FocusTimerSnapshot(seconds: Int(min(Double(Int.max / 2), ceil(remaining))),
                                  fraction: min(1, max(0, remaining / endsAt.timeIntervalSince(startedAt))),
                                  isFinished: now >= endsAt)
    }

    /// The selected clock time belongs to today, never silently to tomorrow.
    public static func finishingToday(at clockTime: Date, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> FocusTimer? {
        let parts = calendar.dateComponents([.hour, .minute], from: clockTime)
        guard let hour = parts.hour, let minute = parts.minute,
              let end = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now),
              calendar.isDate(end, inSameDayAs: now), end > now else { return nil }
        return FocusTimer(startedAt: now, endsAt: end)
    }
}

public struct FocusTimerSnapshot: Equatable, Sendable {
    public let seconds: Int
    public let fraction: Double
    public let isFinished: Bool

    public var clock: String {
        if seconds >= 3600 { return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
