import AppKit
import SwiftUI

final class TileHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }

}

/// Distinguish clicks from drags, then let the Window Server own window movement.
final class TileWindow: NSWindow {
    func setCloseControlHovered(_ hovered: Bool) {
        guard let button = standardWindowButton(.closeButton), button.isHidden != !hovered else { return }
        button.isHidden = !hovered
    }

    var openEditor: (() -> Void)?
    var selectOccasion: (() -> Void)?
    var hasAcknowledgmentButton = false
    private var pendingMouseDown: NSEvent?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDragged, let mouseDown = pendingMouseDown {
            let start = convertPoint(toScreen: mouseDown.locationInWindow)
            let pointer = convertPoint(toScreen: event.locationInWindow)
            if hypot(pointer.x - start.x, pointer.y - start.y) >= 3 {
                // performDrag returns immediately and may consume mouse-up itself.
                pendingMouseDown = nil
                performDrag(with: mouseDown)
            }
            return
        }
        if event.type == .leftMouseUp, pendingMouseDown != nil {
            pendingMouseDown = nil
            selectOccasion?()
            return
        }
        if event.type == .leftMouseDown {
            pendingMouseDown = nil
            let close = standardWindowButton(.closeButton)
            let overClose = close.map { $0.convert($0.bounds, to: nil).contains(event.locationInWindow) } ?? false
            let point = event.locationInWindow
            let scale = min(frame.width / 520, frame.height / 440)
            let footerHeight = max(18, 34 * scale) + max(12, 13 * scale) + 28
            let overAcknowledgment = hasAcknowledgmentButton && point.y < footerHeight
            let overResizeEdge = point.x < 7 || point.x > frame.width - 7 || point.y < 7 || point.y > frame.height - 7
            if !overClose && !overAcknowledgment && !overResizeEdge {
                if event.clickCount >= 2 {
                    openEditor?()
                } else if !styleMask.contains(.fullScreen) {
                    pendingMouseDown = event
                } else {
                    selectOccasion?()
                    super.sendEvent(event)
                }
                return
            }
        }
        super.sendEvent(event)
    }
}
