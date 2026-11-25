import Foundation
import CoreGraphics

/// A layout follows the connected displays, independent of their order, resolution or main display.
public struct DisplaySetup: Equatable, Sendable {
    public let displayIDs: [String]
    public var key: String { displayIDs.joined(separator: "|") }

    public init(displays: [WidgetDisplay]) {
        displayIDs = Array(Set(displays.map(\.id))).sorted()
    }
}

/// Keeps user edits separate from Window Server moves during docking, wake and resolution changes.
/// Only recorded user edits are flushed; transitions never sample already-relocated native windows.
public struct DisplayLayoutSession: Sendable {
    public private(set) var displays: [WidgetDisplay] = []
    public private(set) var isReconfiguring = true
    private var pendingEdits: [UUID: WidgetPlacement] = [:]

    public init() {}

    public var setup: DisplaySetup { DisplaySetup(displays: displays) }

    public func matches(_ currentDisplays: [WidgetDisplay]) -> Bool {
        !currentDisplays.isEmpty && displays.sorted { $0.id < $1.id } == currentDisplays.sorted { $0.id < $1.id }
    }

    public mutating func beginReconfiguration(in library: inout CountdownLibrary) {
        // Preserve the last captured drag even if the 350 ms publication debounce hasn't fired.
        flushEdits(in: &library)
        isReconfiguring = true
    }

    @discardableResult
    public mutating func activate(_ displays: [WidgetDisplay], in library: inout CountdownLibrary) -> Bool {
        guard !displays.isEmpty else { return false }
        flushEdits(in: &library)
        self.displays = displays
        isReconfiguring = false
        ensurePlacements(in: &library)
        return true
    }

    /// Seed newly encountered setups and newly created tiles without changing any other setup.
    public func ensurePlacements(in library: inout CountdownLibrary) {
        guard !isReconfiguring, !displays.isEmpty else { return }
        let key = setup.key
        for index in library.entries.indices where library.entries[index].displayPlacements?[key] == nil {
            if let placement = placement(for: library.entries[index], index: index) {
                if library.entries[index].displayPlacements == nil { library.entries[index].displayPlacements = [:] }
                library.entries[index].displayPlacements?[key] = placement
            }
        }
    }

    public func placement(for entry: CountdownEntry, index: Int = 0) -> WidgetPlacement? {
        if let saved = entry.displayPlacements?[setup.key] { return saved }
        guard let primary = displays.first else { return nil }
        // Existing data is a seed for a new setup, never a replacement for a remembered layout.
        if let saved = entry.placement {
            if displays.contains(where: { $0.id == saved.displayID }) { return saved }
            guard let frame = saved.restoredFrame(on: displays, fallbackDisplayID: primary.id) else { return nil }
            return WidgetPlacement(frame: frame, on: primary)
        }
        let size = entry.countdown.size
        let offset = Double(index % 6) * 28
        return WidgetPlacement(x: (primary.visibleFrame.width - size.width) / 2 + offset,
                               y: (primary.visibleFrame.height - size.height) / 2 - offset,
                               width: size.width, height: size.height, displayID: primary.id)
    }

    /// The caller supplies only intentional moves/resizes, captured at notification time.
    @discardableResult
    public mutating func recordEdit(_ placement: WidgetPlacement, for id: UUID, currentDisplays: [WidgetDisplay]) -> Bool {
        guard !isReconfiguring, matches(currentDisplays), placement.isValid,
              displays.contains(where: { $0.id == placement.displayID }) else { return false }
        pendingEdits[id] = placement
        return true
    }

    public mutating func flushEdits(in library: inout CountdownLibrary) {
        guard !displays.isEmpty else { return }
        let key = setup.key
        for (id, placement) in pendingEdits {
            library.update(id) {
                if $0.displayPlacements == nil { $0.displayPlacements = [:] }
                $0.displayPlacements?[key] = placement
                $0.placement = placement
            }
        }
        pendingEdits.removeAll()
    }
}

extension WidgetPlacement {
    public init(frame: CGRect, on display: WidgetDisplay) {
        self.init(x: frame.minX - display.visibleFrame.minX, y: frame.minY - display.visibleFrame.minY,
                  width: frame.width, height: frame.height, displayID: display.id)
    }
}
