import Foundation
import CoreGraphics

public struct WidgetPlacement: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var displayID: String

    public init(x: Double, y: Double, width: Double, height: Double, displayID: String) {
        self.x = x; self.y = y; self.width = width; self.height = height; self.displayID = displayID
    }

    public var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && width >= 100 && height >= 100
    }

    /// Offsets are relative to the saved display, so rearranging monitors is safe.
    public func frame(in visibleFrame: CGRect) -> CGRect {
        let w = min(max(WidgetSize.extraSmall.width, width), visibleFrame.width)
        let h = min(max(WidgetSize.extraSmall.height, height), visibleFrame.height)
        return CGRect(x: visibleFrame.minX + min(max(0, x), visibleFrame.width - w),
                      y: visibleFrame.minY + min(max(0, y), visibleFrame.height - h), width: w, height: h)
    }
}

public struct CountdownEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var countdown: Countdown
    public var isVisible: Bool
    public var placement: WidgetPlacement?
    public var timer: FocusTimer?

    public init(id: UUID = UUID(), countdown: Countdown = Countdown(), isVisible: Bool = true, placement: WidgetPlacement? = nil, timer: FocusTimer? = nil) {
        self.id = id; self.countdown = countdown; self.isVisible = isVisible; self.placement = placement
        self.timer = timer
    }
}

public struct CountdownLibrary: Codable, Equatable, Sendable {
    public var version = 3
    public var entries: [CountdownEntry]
    public var selectedID: UUID?

    public init(entries: [CountdownEntry] = [CountdownEntry()]) {
        self.entries = entries; selectedID = entries.first?.id
    }

    public var selected: CountdownEntry? { entries.first { $0.id == selectedID } }
    public var isValid: Bool {
        version == 3 && Set(entries.map(\.id)).count == entries.count
            && entries.allSatisfy { $0.countdown.isValid && ($0.placement?.isValid ?? true) && ($0.timer?.isValid ?? true) && ($0.timer == nil || $0.countdown.style == .ring) }
            && (entries.isEmpty ? selectedID == nil : selected != nil)
    }

    @discardableResult public mutating func add(_ countdown: Countdown = Countdown()) -> UUID {
        let entry = CountdownEntry(countdown: countdown)
        entries.append(entry); selectedID = entry.id
        return entry.id
    }

    @discardableResult public mutating func duplicate(_ id: UUID) -> UUID? {
        guard let original = entries.first(where: { $0.id == id }), original.timer == nil else { return nil }
        var value = original.countdown
        value.title = String((value.displayTitle + " copy").prefix(120))
        return add(value)
    }

    @discardableResult public mutating func addTimer(_ timer: FocusTimer, title: String = "Focus timer") -> UUID? {
        guard timer.isValid else { return nil }
        var appearance = Countdown(now: timer.startedAt)
        appearance.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Focus timer" : String(title.prefix(120))
        appearance.style = .ring; appearance.size = .compact
        let entry = CountdownEntry(countdown: appearance, timer: timer)
        entries.append(entry); selectedID = entry.id
        return entry.id
    }

    @discardableResult public mutating func acknowledgeTimer(_ id: UUID, at now: Date = Date()) -> Bool {
        guard let timer = entries.first(where: { $0.id == id })?.timer, timer.snapshot(at: now).isFinished else { return false }
        remove(id)
        return true
    }

    @discardableResult public mutating func remove(_ id: UUID) -> CountdownEntry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = entries.remove(at: index)
        if selectedID == id { selectedID = entries.isEmpty ? nil : entries[min(index, entries.count - 1)].id }
        return removed
    }

    public mutating func update(_ id: UUID, _ change: (inout CountdownEntry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        change(&entries[index])
    }
}

public enum CountdownLibraryFile {
    public struct Loaded {
        public let library: CountdownLibrary
        public let migrated: Bool
    }

    public static func read(from url: URL) throws -> Loaded {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let decoder = JSONDecoder()
        if object?["version"] != nil || object?["entries"] != nil {
            var library = try decoder.decode(CountdownLibrary.self, from: data)
            let migrated = library.version == 2
            if migrated { library.version = 3 }
            guard library.isValid else { throw CocoaError(.coderReadCorrupt) }
            return Loaded(library: library, migrated: migrated)
        }
        let countdown = try decoder.decode(Countdown.self, from: data)
        guard countdown.isValid else { throw CocoaError(.coderReadCorrupt) }
        return Loaded(library: CountdownLibrary(entries: [CountdownEntry(countdown: countdown)]), migrated: true)
    }

    public static func write(_ library: CountdownLibrary, to url: URL) throws {
        guard library.isValid else { throw CocoaError(.coderInvalidValue) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(library).write(to: url, options: .atomic)
    }
}
