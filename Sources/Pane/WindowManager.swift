import AppKit
import ApplicationServices

enum WindowManager {
    static func focusedWindow() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppRef
        ) == .success, let appRef = focusedAppRef else { return nil }
        let app = appRef as! AXUIElement

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            app, kAXFocusedWindowAttribute as CFString, &windowRef
        ) == .success, let w = windowRef else { return nil }
        return (w as! AXUIElement)
    }

    static func setFrame(_ frame: CGRect, for window: AXUIElement) {
        // Electron and similar wrapper-app windows ignore AX position/size
        // writes while their parent application has `AXEnhancedUserInterface`
        // turned on. Flipping it off for the duration of the write makes the
        // change stick; we restore the original value afterward.
        let app = parentApplication(of: window)
        let enhancedWasOn = app.map(readEnhancedUI) ?? false
        if let app, enhancedWasOn {
            AXUIElementSetAttributeValue(app, kAXEnhancedUIAttr, kCFBooleanFalse)
        }

        var pos = frame.origin
        var size = frame.size
        if let posValue = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
        // Second pass — some apps clamp size on the first apply.
        if let posValue = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }

        if let app, enhancedWasOn {
            AXUIElementSetAttributeValue(app, kAXEnhancedUIAttr, kCFBooleanTrue)
        }
    }

    private static let kAXEnhancedUIAttr = "AXEnhancedUserInterface" as CFString

    private static func parentApplication(of window: AXUIElement) -> AXUIElement? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return nil }
        return AXUIElementCreateApplication(pid)
    }

    private static func readEnhancedUI(_ app: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXEnhancedUIAttr, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    static func frame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let pos = posRef, let size = sizeRef else { return nil }
        var origin = CGPoint.zero
        var dim = CGSize.zero
        AXValueGetValue(pos as! AXValue, .cgPoint, &origin)
        AXValueGetValue(size as! AXValue, .cgSize, &dim)
        return CGRect(origin: origin, size: dim)
    }

    /// Walks up from the element at `point` (AX coords) to its enclosing window.
    /// Falls back to enumerating app windows if hit-test fails — Electron and
    /// some web-based apps don't expose elements via AXUIElementCopyElementAt-
    /// Position, but their windows are still reachable via kAXWindowsAttribute.
    static func windowUnder(point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        if AXUIElementCopyElementAtPosition(
            systemWide, Float(point.x), Float(point.y), &element
        ) == .success, var current = element {
            for _ in 0..<20 {
                var role: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &role)
                if let r = role as? String, r == kAXWindowRole as String { return current }
                var parent: CFTypeRef?
                guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                      let p = parent else { break }
                current = p as! AXUIElement
            }
        }
        return enumerateWindow(containing: point)
    }

    private static func enumerateWindow(containing point: CGPoint) -> AXUIElement? {
        // Focused app first (fastest path, covers the common case).
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppRef) == .success,
           let appRef = focusedAppRef {
            let app = appRef as! AXUIElement
            if let w = findWindow(in: app, containing: point) { return w }
        }
        for running in NSWorkspace.shared.runningApplications {
            guard running.activationPolicy == .regular,
                  !running.isTerminated,
                  running.processIdentifier > 0 else { continue }
            let axApp = AXUIElementCreateApplication(running.processIdentifier)
            if let w = findWindow(in: axApp, containing: point) { return w }
        }
        return nil
    }

    private static func findWindow(in app: AXUIElement, containing point: CGPoint) -> AXUIElement? {
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return nil }
        for window in windows {
            if let f = frame(of: window), f.contains(point) { return window }
        }
        return nil
    }
}
