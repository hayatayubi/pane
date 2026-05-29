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
        NSLog("Pane: CGEventTap installed (mouseDown only)")
    }

    deinit {
        pollTimer?.cancel()
        if let s = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        if let t = eventTap { CGEvent.tapEnable(tap: t, enable: false) }
    }

    fileprivate func reenableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            NSLog("Pane: CGEventTap re-enabled")
        }
    }

    // MARK: - Mouse down → start polling

    private func handleMouseDown(at point: CGPoint) {
        guard let window = WindowManager.windowUnder(point: point) else {
            NSLog("Pane: mouseDown — no window at \(point)")
            return
        }
        guard let frame = WindowManager.frame(of: window) else {
            NSLog("Pane: mouseDown — couldn't read window frame")
            return
        }
        // Use top 56pt of the window as the drag strip — covers thicker
        // Electron / Chromium / custom title bars too.
        let titleStrip = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 56)
        guard titleStrip.contains(point) else {
            NSLog("Pane: mouseDown not in titleStrip point=\(point) strip=\(titleStrip)")
            return
        }

        draggedWindow = window
        dragStartAX = point
        dragging = false
        overlayShown = false
        NSLog("Pane: title-bar press; starting poll (frame=\(frame))")
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
            if dx*dx + dy*dy >= dragThreshold * dragThreshold {
                dragging = true
                NSLog("Pane: drag threshold passed")
            } else { return }
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
            NSLog("Pane: applying \(zone.rawValue)")
            zone.apply(to: window)
        }
        overlay.hide()
    }

    private func reset() {
        draggedWindow = nil
        dragging = false
        overlayShown = false
        overlayScreen = nil
    }
}
