import AppKit

// AX/CG global coordinates put the origin at the TOP-left of the primary screen.
// AppKit puts the origin at the BOTTOM-left. Anything that talks to AXUIElement,
// CGEvent, or AXUIElementCopyElementAtPosition lives in the former; NSWindow,
// NSScreen.frame, NSEvent.mouseLocation live in the latter.
enum ScreenCoords {
    static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    static func appKitToAX(_ point: NSPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    static func axToAppKit(_ point: CGPoint) -> NSPoint {
        NSPoint(x: point.x, y: primaryHeight - point.y)
    }

    static func screenContainingAX(_ point: CGPoint) -> NSScreen? {
        let appKit = axToAppKit(point)
        return NSScreen.screens.first { $0.frame.contains(appKit) }
    }

    static var mouseLocationAX: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }
}
