import AppKit
import ApplicationServices

enum SnapZone: String, CaseIterable, Sendable {
    case topLeft, topHalf, topRight
    case leftHalf, maximize, rightHalf
    case bottomLeft, bottomHalf, bottomRight

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
        }
    }

    func apply(to window: AXUIElement? = nil) {
        guard let w = window ?? WindowManager.focusedWindow() else { return }
        let screen = screenForWindow(w) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
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

        let edge: CGFloat = 6        // "touching the edge"
        let corner: CGFloat = 80     // corner trigger reach along each axis

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
        }
    }
}
