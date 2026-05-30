import AppKit
import ApplicationServices

enum SnapZone: String, CaseIterable, Sendable {
    case topLeft, topHalf, topRight
    case leftHalf, maximize, rightHalf
    case bottomLeft, bottomHalf, bottomRight
    case center

    var symbolName: String {
        switch self {
        case .topLeft:     return "rectangle.inset.topleading.filled"
        case .topHalf:     return "rectangle.tophalf.inset.filled"
        case .topRight:    return "rectangle.inset.toptrailing.filled"
        case .leftHalf:    return "rectangle.lefthalf.inset.filled"
        case .maximize:    return "rectangle.fill"
        case .rightHalf:   return "rectangle.righthalf.inset.filled"
        case .bottomLeft:  return "rectangle.inset.bottomleading.filled"
        case .bottomHalf:  return "rectangle.bottomhalf.inset.filled"
        case .bottomRight: return "rectangle.inset.bottomtrailing.filled"
        case .center:      return "dot.viewfinder"
        }
    }

    func axFrame(in screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        let topY = ScreenCoords.primaryHeight - visible.maxY
        let halfW = floor(visible.width / 2)
        let halfH = floor(visible.height / 2)

        switch self {
        case .topLeft:
            return CGRect(x: visible.minX, y: topY, width: halfW, height: halfH)
        case .topHalf:
            return CGRect(x: visible.minX, y: topY, width: visible.width, height: halfH)
        case .topRight:
            return CGRect(x: visible.minX + halfW, y: topY, width: visible.width - halfW, height: halfH)
        case .leftHalf:
            return CGRect(x: visible.minX, y: topY, width: halfW, height: visible.height)
        case .maximize:
            return CGRect(x: visible.minX, y: topY, width: visible.width, height: visible.height)
        case .rightHalf:
            return CGRect(x: visible.minX + halfW, y: topY, width: visible.width - halfW, height: visible.height)
        case .bottomLeft:
            return CGRect(x: visible.minX, y: topY + halfH, width: halfW, height: visible.height - halfH)
        case .bottomHalf:
            return CGRect(x: visible.minX, y: topY + halfH, width: visible.width, height: visible.height - halfH)
        case .bottomRight:
            return CGRect(x: visible.minX + halfW, y: topY + halfH, width: visible.width - halfW, height: visible.height - halfH)
        case .center:
            // Used only as a fallback when we don't know the window's current
            // size — apply(to:) overrides this with the actual window size.
            let w = floor(visible.width * 0.6)
            let h = floor(visible.height * 0.6)
            return CGRect(
                x: visible.minX + (visible.width - w) / 2,
                y: topY + (visible.height - h) / 2,
                width: w, height: h
            )
        }
    }

    func apply(to window: AXUIElement? = nil) {
        guard let w = window ?? WindowManager.focusedWindow() else { return }
        let screen = screenForWindow(w) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        // Stash the pre-snap frame so a quick re-drag within the next few
        // seconds reverts the window to its previous size.
        if let preSnap = WindowManager.frame(of: w) {
            SnapHistory.record(window: w, preSnapFrame: preSnap)
        }

        // Center preserves the window's current size — just repositions it.
        if self == .center, let current = WindowManager.frame(of: w) {
            let visible = screen.visibleFrame
            let topY = ScreenCoords.primaryHeight - visible.maxY
            let frame = CGRect(
                x: visible.minX + (visible.width - current.width) / 2,
                y: topY + (visible.height - current.height) / 2,
                width: current.width,
                height: current.height
            )
            WindowManager.setFrame(frame, for: w)
            return
        }

        WindowManager.setFrame(axFrame(in: screen), for: w)
    }

    private func screenForWindow(_ window: AXUIElement) -> NSScreen? {
        guard let frame = WindowManager.frame(of: window) else { return nil }
        let centerAX = CGPoint(x: frame.midX, y: frame.midY)
        return ScreenCoords.screenContainingAX(centerAX)
    }

    // MARK: - Aero-style trigger detection & local rect for outlines

    /// Returns the snap zone whose trigger region contains `axPoint`, or nil
    /// if the cursor is in free space.
    static func zone(forCursor axPoint: CGPoint, on screen: NSScreen) -> SnapZone? {
        let visible = screen.visibleFrame
        let topAX = ScreenCoords.primaryHeight - visible.maxY
        let leftAX = visible.minX
        let rightAX = leftAX + visible.width
        let bottomAX = topAX + visible.height

        // Trigger thresholds come from the user's chosen sensitivity. `edge`
        // is the proximity at which a half-screen snap activates; `corner`
        // is how far along the perpendicular axis still counts as a corner.
        let sensitivity = SensitivityStore.shared.sensitivity
        let edge = sensitivity.edgeProximity
        let corner = sensitivity.cornerReach

        let nearTop    = axPoint.y <= topAX + edge
        let nearBottom = axPoint.y >= bottomAX - edge
        let nearLeft   = axPoint.x <= leftAX + edge
        let nearRight  = axPoint.x >= rightAX - edge

        let inLeftReach   = axPoint.x <= leftAX + corner
        let inRightReach  = axPoint.x >= rightAX - corner
        let inTopReach    = axPoint.y <= topAX + corner
        let inBottomReach = axPoint.y >= bottomAX - corner

        if (nearTop && inLeftReach) || (nearLeft && inTopReach) { return .topLeft }
        if (nearTop && inRightReach) || (nearRight && inTopReach) { return .topRight }
        if (nearBottom && inLeftReach) || (nearLeft && inBottomReach) { return .bottomLeft }
        if (nearBottom && inRightReach) || (nearRight && inBottomReach) { return .bottomRight }
        if nearTop    { return .maximize }
        if nearBottom { return .bottomHalf }
        if nearLeft   { return .leftHalf }
        if nearRight  { return .rightHalf }
        return nil
    }

    /// Rect within the visible-area's local coordinate space (top-left origin),
    /// for drawing the outline overlay.
    static func localRect(for zone: SnapZone, in size: CGSize) -> CGRect {
        let halfW = floor(size.width / 2)
        let halfH = floor(size.height / 2)
        switch zone {
        case .topLeft:     return CGRect(x: 0,     y: 0,     width: halfW,             height: halfH)
        case .topHalf:     return CGRect(x: 0,     y: 0,     width: size.width,        height: halfH)
        case .topRight:    return CGRect(x: halfW, y: 0,     width: size.width - halfW, height: halfH)
        case .leftHalf:    return CGRect(x: 0,     y: 0,     width: halfW,             height: size.height)
        case .maximize:    return CGRect(origin: .zero, size: size)
        case .rightHalf:   return CGRect(x: halfW, y: 0,     width: size.width - halfW, height: size.height)
        case .bottomLeft:  return CGRect(x: 0,     y: halfH, width: halfW,             height: size.height - halfH)
        case .bottomHalf:  return CGRect(x: 0,     y: halfH, width: size.width,        height: size.height - halfH)
        case .bottomRight: return CGRect(x: halfW, y: halfH, width: size.width - halfW, height: size.height - halfH)
        case .center:
            // Not drag-triggered, but provide a representative centered rect
            // so the switch is exhaustive and any caller has a sensible value.
            let w = floor(size.width * 0.6)
            let h = floor(size.height * 0.6)
            return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
        }
    }
}
