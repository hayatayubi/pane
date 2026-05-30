import ApplicationServices
import CoreGraphics
import Foundation

/// Remembers the pre-snap frame of the most recently snapped window so a
/// quick drag immediately after snapping reverts the window to its
/// previous size. Active for `undoWindow` seconds.
///
/// Accessed only from the main thread, so a plain enum + static state is
/// fine — no locking needed.
enum SnapHistory {
    static let undoWindow: TimeInterval = 3.0

    private(set) static var lastWindow: AXUIElement?
    private(set) static var preSnapFrame: CGRect?
    private(set) static var timestamp: Date?

    /// Called by `SnapZone.apply` before any frame is written. If we're
    /// already tracking the same window within the undo window, we *refresh*
    /// the timestamp but keep the original pre-snap frame — so rapidly
    /// snapping a window to several zones still lets the user revert to
    /// the true pre-snap state, not an intermediate snap.
    static func record(window: AXUIElement, preSnapFrame: CGRect) {
        if let last = lastWindow, let ts = timestamp,
           CFEqual(last, window),
           Date().timeIntervalSince(ts) <= undoWindow {
            timestamp = Date()
            return
        }
        lastWindow = window
        Self.preSnapFrame = preSnapFrame
        timestamp = Date()
    }

    /// If `window` was snapped within the undo window, returns the pre-snap
    /// frame and clears the history (consumed). Otherwise returns nil.
    static func consumeRestoreFrame(for window: AXUIElement) -> CGRect? {
        guard let last = lastWindow,
              let frame = preSnapFrame,
              let ts = timestamp,
              CFEqual(last, window),
              Date().timeIntervalSince(ts) <= undoWindow
        else { return nil }
        clear()
        return frame
    }

    static func clear() {
        lastWindow = nil
        preSnapFrame = nil
        timestamp = nil
    }
}
