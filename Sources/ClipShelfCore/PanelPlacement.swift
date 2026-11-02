import Foundation

public enum PanelPlacement {
    static let margin: CGFloat = 8

    /// Where to put the panel: centered below `anchor` (the menu bar icon) if given, otherwise with
    /// its top-left corner just above-left of the mouse. Always kept inside `visibleFrame`, preferring
    /// to keep the top edge visible when the panel is taller than the screen.
    public static func origin(size: CGSize, anchor: CGRect?, mouse: CGPoint, visibleFrame: CGRect) -> CGPoint {
        var origin: CGPoint
        if let anchor {
            origin = CGPoint(x: anchor.midX - size.width / 2, y: anchor.minY - size.height - 4)
        } else {
            origin = CGPoint(x: mouse.x - 20, y: mouse.y - size.height + 20)
        }
        origin.x = max(min(origin.x, visibleFrame.maxX - size.width - margin), visibleFrame.minX + margin)
        origin.y = min(max(origin.y, visibleFrame.minY + margin), visibleFrame.maxY - size.height - margin)
        return origin
    }
}
