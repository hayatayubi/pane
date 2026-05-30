import AppKit
import SwiftUI

final class SnapOverlayModel: ObservableObject {
    @Published var activeZone: SnapZone?
}

/// A transparent, full-screen panel that draws the outline of the snap zone
/// the cursor is currently over. The panel ignores mouse events so it never
/// blocks the actual window drag.
final class SnapOverlayWindow {
    private var panel: NSPanel?
    private let model = SnapOverlayModel()
    private(set) var currentScreen: NSScreen?

    func show(on screen: NSScreen) {
        if currentScreen != screen || panel == nil {
            rebuildPanel(for: screen)
            currentScreen = screen
        }
        guard let panel else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        model.activeZone = nil
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    func updateHighlight(axPoint: CGPoint) {
        guard let screen = currentScreen else { return }
        model.activeZone = SnapZone.zone(forCursor: axPoint, on: screen)
    }

    func zoneAtAX(point: CGPoint) -> SnapZone? {
        guard let screen = currentScreen else { return nil }
        return SnapZone.zone(forCursor: point, on: screen)
    }

    private func rebuildPanel(for screen: NSScreen) {
        panel?.orderOut(nil)
        let frame = screen.visibleFrame
        let p = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView: SnapOutlineView(model: model, size: frame.size))
        panel = p
    }
}

private struct SnapOutlineView: View {
    @ObservedObject var model: SnapOverlayModel
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if let zone = model.activeZone {
                let rect = SnapZone.localRect(for: zone, in: size)
                ZoneOutline()
                    .frame(width: max(0, rect.width - 16), height: max(0, rect.height - 16))
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.spring(response: 0.26, dampingFraction: 0.86), value: model.activeZone)
    }
}

private struct ZoneOutline: View {
    @ObservedObject private var appearance = AppearanceStore.shared

    var body: some View {
        let color = appearance.outlineColor
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(color.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(color.opacity(0.95), lineWidth: 2.5)
            )
            .shadow(color: color.opacity(0.35), radius: 14)
    }
}
