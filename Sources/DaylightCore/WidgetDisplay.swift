import Foundation
import CoreGraphics

public struct WidgetDisplay: Equatable, Sendable {
    public let id: String
    public let visibleFrame: CGRect

    public init(id: String, visibleFrame: CGRect) {
        self.id = id
        self.visibleFrame = visibleFrame
    }
}

extension WidgetPlacement {
    /// A fallback is temporary: resolving a frame never changes the preferred display or size.
    public func restoredFrame(on displays: [WidgetDisplay], fallbackDisplayID: String? = nil) -> CGRect? {
        if let display = displays.first(where: { $0.id == displayID }) {
            return frame(in: display.visibleFrame)
        }
        guard let fallback = displays.first(where: { $0.id == fallbackDisplayID }) ?? displays.first else { return nil }
        var centered = self
        centered.x = (fallback.visibleFrame.width - min(width, fallback.visibleFrame.width)) / 2
        centered.y = (fallback.visibleFrame.height - min(height, fallback.visibleFrame.height)) / 2
        return centered.frame(in: fallback.visibleFrame)
    }

}
