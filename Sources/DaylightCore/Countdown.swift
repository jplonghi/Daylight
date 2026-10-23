import Foundation

/// A civil date, rather than a UTC instant: November 20 stays November 20 when you travel.
public struct LocalDay: Codable, Equatable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    public func date(in calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantFuture
    }

    public func isValid(in calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return false }
        return LocalDay(date, calendar: calendar) == self
    }
}

public enum CountdownStyle: String, Codable, CaseIterable, Sendable {
    case number, ring, flip, grid
    public var title: String { switch self { case .number: "Number"; case .ring: "Ring"; case .flip: "Flip clock"; case .grid: "Day grid" } }
}

public enum WidgetTheme: String, Codable, CaseIterable, Sendable {
    case midnight, paper, sand, forest
    public var title: String { rawValue.capitalized }
}

public enum Accent: String, Codable, CaseIterable, Sendable {
    case coral, gold, mint, blue, rose
    public var title: String { rawValue.capitalized }
}

public enum WidgetSize: String, Codable, CaseIterable, Sendable {
    case extraSmall, compact, comfortable, large
    public var title: String { switch self { case .extraSmall: "X-small"; case .compact: "Small"; case .comfortable: "Medium"; case .large: "Large" } }
    public var width: Double { switch self { case .extraSmall: 260; case .compact: 360; case .comfortable: 560; case .large: 900 } }
    public var height: Double { switch self { case .extraSmall: 240; case .compact: 320; case .comfortable: 460; case .large: 650 } }
}

public enum PalettePreset: String, CaseIterable, Sendable {
    case ember, moonlight, porcelain, dune, grove, blossom, aurora, canopy, tide, clay
    public var title: String { rawValue.capitalized }
    public var theme: WidgetTheme {
        switch self { case .ember, .moonlight, .aurora: .midnight; case .porcelain, .blossom, .clay: .paper; case .dune, .tide: .sand; case .grove, .canopy: .forest }
    }
    public var accent: Accent {
        switch self { case .ember, .clay: .coral; case .moonlight, .porcelain, .tide: .blue; case .dune, .canopy: .gold; case .grove, .aurora: .mint; case .blossom: .rose }
    }
    public func apply(to countdown: inout Countdown) {
        countdown.theme = theme; countdown.accent = accent
    }
}

public struct Countdown: Codable, Equatable, Sendable {
    public var title: String
    public var target: LocalDay
    public var started: LocalDay
    public var style: CountdownStyle
    public var theme: WidgetTheme
    public var accent: Accent
    public var size: WidgetSize
    public var alwaysOnTop: Bool
    public var allSpaces: Bool

    public init(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) {
        title = "My next big day"
        target = LocalDay(calendar.date(byAdding: .day, value: 30, to: now)!, calendar: calendar)
        started = LocalDay(now, calendar: calendar)
        style = .ring; theme = .midnight; accent = .coral; size = .comfortable
        alwaysOnTop = false; allSpaces = false
    }

    public var displayTitle: String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "My next big day" : cleaned
    }

    public var isValid: Bool { target.isValid() && started.isValid() }

    public func snapshot(at now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> CountdownSnapshot {
        let end = calendar.startOfDay(for: target.date(in: calendar))
        let start = calendar.startOfDay(for: started.date(in: calendar))
        let today = calendar.startOfDay(for: now)
        let signedDays = calendar.dateComponents([.day], from: today, to: end).day ?? 0
        let duration = end.timeIntervalSince(start)
        let remaining = max(0, end.timeIntervalSince(now))
        let progress = duration > 0 ? min(1, max(0, remaining / duration)) : 0
        let parts = calendar.dateComponents([.day, .hour, .minute], from: now, to: max(now, end))
        return CountdownSnapshot(
            days: max(0, signedDays), isToday: signedDays == 0, hasPassed: signedDays < 0,
            remainingFraction: progress,
            fullDays: max(0, parts.day ?? 0), hours: max(0, parts.hour ?? 0), minutes: max(0, parts.minute ?? 0)
        )
    }
}

public struct CountdownSnapshot: Equatable, Sendable {
    public let days: Int
    public let isToday: Bool
    public let hasPassed: Bool
    public let remainingFraction: Double
    public let fullDays: Int
    public let hours: Int
    public let minutes: Int
    public var caption: String {
        if isToday { return "Today’s the day" }
        if hasPassed { return "That day has arrived" }
        return days == 1 ? "day to go" : "days to go"
    }
}

public enum CountdownFile {
    public static func read(from url: URL) throws -> Countdown {
        let value = try JSONDecoder().decode(Countdown.self, from: Data(contentsOf: url))
        guard value.isValid else { throw CocoaError(.coderReadCorrupt) }
        return value
    }

    public static func write(_ value: Countdown, to url: URL) throws {
        guard value.isValid else { throw CocoaError(.coderInvalidValue) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
