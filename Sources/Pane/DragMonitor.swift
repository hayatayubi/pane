import AppKit
import ApplicationServices
import CoreGraphics

/// Detects window drags and drives the snap overlay.
///
/// Why this is structured oddly: while macOS's WindowServer is actively
/// tracking a window drag, `mouseDragged`/`mouseUp` events are NOT delivered
/// to event taps or NSEvent global monitors. `mouseDown` *is* delivered. So
/// we use a CGEventTap only to detect the title-bar press, then switch to a
/// 60Hz polling loop that reads cursor position and button state directly
/// from the OS — those calls work regardless of who's tracking the drag.
final class DragMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: DispatchSourceTimer?

    private var draggedWindow: AXUIElement?
    private var dragStartAX: CGPoint = .zero
    private var dragStartFrame: CGRect = .zero
    private var dragging = false
    private var overlayShown = false
    private var overlayScreen: NSScreen?
    private let overlay = SnapOverlayWindow()

    private let dragThreshold: CGFloat = 6

    func start() {
        let mask: CGEventMask = 1 << CGEventType.leftMouseDown.rawValue
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let userInfo {
                        let m = Unmanaged<DragMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                        DispatchQueue.main.async { m.reenableTap() }
                    }
                    return Unmanaged.passUnretained(event)
                }
                if type == .leftMouseDown, let userInfo {
                    let m = Unmanaged<DragMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                    let loc = event.location
                    DispatchQueue.main.async { m.handleMouseDown(at: loc) }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            NSLog("Pane: ERROR — CGEvent.tapCreate returned nil")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    deinit {
        pollTimer?.cancel()
        if let s = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        if let t = eventTap { CGEvent.tapEnable(tap: t, enable: false) }
    }

    fileprivate func reenableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    // MARK: - Mouse down → start polling

    private func handleMouseDown(at point: CGPoint) {
        guard let window = WindowManager.windowUnder(point: point),
              let frame = WindowManager.frame(of: window) else { return }
        // Top 56pt of the window is the drag strip — wide enough to cover
        // thicker Electron / Chromium / custom title bars.
        let titleStrip = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 56)
        guard titleStrip.contains(point) else { return }
        if ExclusionStore.shared.isDragBlocked(bundleID: AXApp.bundleID(of: window)) { return }

        draggedWindow = window
        dragStartAX = point
        dragStartFrame = frame
        dragging = false
        overlayShown = false
        startPolling()
    }

    // MARK: - 60Hz polling

    private func startPolling() {
        pollTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(16), repeating: .milliseconds(16))
        timer.setEventHandler { [weak self] in self?.pollTick() }
        timer.resume()
        pollTimer = timer
    }

    private func pollTick() {
        let pressed = (NSEvent.pressedMouseButtons & 0x1) != 0
        let point = ScreenCoords.mouseLocationAX

        guard pressed else {
            finishDrag(at: point)
            return
        }

        if !dragging {
            let dx = point.x - dragStartAX.x
            let dy = point.y - dragStartAX.y
            guard dx*dx + dy*dy >= dragThreshold * dragThreshold else { return }
            dragging = true

            // Snap-undo: if this window was snapped within the last few
            // seconds, restore its pre-snap size now and position it so the
            // title bar stays under the cursor — that way the drag continues
            // smoothly into whatever the user wants to do with the window.
            if let window = draggedWindow,
               let restoreFrame = SnapHistory.consumeRestoreFrame(for: window) {
                let snappedWidth  = max(dragStartFrame.width,  1)
                let relX = (dragStartAX.x - dragStartFrame.minX) / snappedWidth
                let newX = point.x - relX * restoreFrame.width
                // Keep the cursor on the title bar: ~12pt below the top edge.
                let newY = max(0, point.y - 12)
                let target = CGRect(
                    x: newX, y: newY,
                    width: restoreFrame.width,
                    height: restoreFrame.height
                )
                WindowManager.setFrame(target, for: window)
            }
        }

        updateOverlay(at: point)
    }

    private func updateOverlay(at point: CGPoint) {
        guard let screen = ScreenCoords.screenContainingAX(point) else {
            if overlayShown { overlay.hide(); overlayShown = false; overlayScreen = nil }
            return
        }
        if !overlayShown || overlayScreen != screen {
            overlay.show(on: screen)
            overlayShown = true
            overlayScreen = screen
        }
        overlay.updateHighlight(axPoint: point)
    }

    private func finishDrag(at point: CGPoint) {
        pollTimer?.cancel()
        pollTimer = nil
        defer { reset() }
        guard overlayShown, let window = draggedWindow else {
            if overlayShown { overlay.hide() }
            return
        }
        if let zone = overlay.zoneAtAX(point: point) {
            zone.apply(to: window)
        }
        overlay.hide()
    }

    private func reset() {
        draggedWindow = nil
        dragStartFrame = .zero
        dragging = false
        overlayShown = false
        overlayScreen = nil
    }
}
