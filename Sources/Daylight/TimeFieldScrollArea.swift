import AppKit
import SwiftUI

enum FinishTimePart {
    case hour, minute

    func adjusting(_ text: String, by steps: Int) -> String {
        let range = self == .hour ? 1...12 : 0...59
        let count = range.count
        let parsed = Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
        // An empty or invalid field recovers to its first valid value.
        guard let value = parsed, range.contains(value) else {
            return self == .hour ? "1" : "00"
        }
        let offset = (value - range.lowerBound + steps % count) % count
        let result = range.lowerBound + (offset + count) % count
        return self == .hour ? String(result) : String(format: "%02d", result)
    }
}

/// Trackpads send many small deltas. Accumulate them, but discard momentum and
/// partial movement from an earlier gesture or from the opposite direction.
struct TimeFieldScrollSteps {
    private var remainder: CGFloat = 0
    private var lastTimestamp: TimeInterval = 0

    mutating func consume(delta: CGFloat, precise: Bool, momentum: Bool,
                          newGesture: Bool, timestamp: TimeInterval) -> Int {
        guard !momentum else { remainder = 0; return 0 }
        if newGesture || timestamp - lastTimestamp > 0.3 || delta * remainder < 0 {
            remainder = 0
        }
        lastTimestamp = timestamp
        guard delta.isFinite, delta != 0 else { return 0 }
        guard precise else { remainder = 0; return delta > 0 ? 1 : -1 }
        remainder += delta
        let steps = Int(remainder / 20)
        remainder -= CGFloat(steps) * 20
        return steps
    }
}

/// Observes scrolling only over the field. Mouse clicks and text editing continue
/// to reach the SwiftUI TextField, including its native field editor.
struct TimeFieldScrollArea: NSViewRepresentable {
    var adjust: (Int) -> Void

    func makeNSView(context: Context) -> ScrollView {
        let view = ScrollView()
        view.adjust = adjust
        return view
    }

    func updateNSView(_ view: ScrollView, context: Context) { view.adjust = adjust }
    static func dismantleNSView(_ view: ScrollView, coordinator: ()) { view.stopMonitoring() }

    final class ScrollView: NSView {
        var adjust: ((Int) -> Void)?
        private var monitor: Any?
        private var steps = TimeFieldScrollSteps()

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                let consumed = MainActor.assumeIsolated {
                    guard let self else { return false }
                    return self.handleScroll(event) == nil
                }
                return consumed ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            steps = TimeFieldScrollSteps()
        }

        func handleScroll(_ event: NSEvent) -> NSEvent? {
            guard let window, event.window === window, !isHiddenOrHasHiddenAncestor,
                  bounds.contains(convert(event.locationInWindow, from: nil)) else {
                steps = TimeFieldScrollSteps()
                return event
            }
            let change = steps.consume(delta: event.scrollingDeltaY,
                                       precise: event.hasPreciseScrollingDeltas,
                                       momentum: !event.momentumPhase.isEmpty,
                                       newGesture: event.phase.contains(.began), timestamp: event.timestamp)
            if change != 0 { adjust?(change) }
            return nil
        }
    }
}
