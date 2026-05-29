import AppKit
import ApplicationServices
import Combine
import os

private let log = Logger(subsystem: "com.local.pane", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var dragMonitor: DragMonitor?
    private var hotkeyManager: HotkeyManager?
    private var permissionTimer: Timer?
    private var bindingsCancellable: AnyCancellable?
    private var hasPermission = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("applicationDidFinishLaunching")
        NSLog("Pane: applicationDidFinishLaunching")

        // Status item FIRST — the user always needs a way to see and quit the app,
        // regardless of permission state.
        setupStatusItem()

        // System-level prompt; non-blocking. macOS shows its own dialog if needed.
        hasPermission = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        )
        NSLog("Pane: initial accessibility trusted = %d", hasPermission ? 1 : 0)
        updateStatusItemAppearance()

        startMonitorsIfPossible()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recheckPermission()
        }
        bindingsCancellable = HotkeyStore.shared.$bindings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else {
            NSLog("Pane: ERROR — status item has no button")
            return
        }
        applyButtonAppearance(button)
        NSLog("Pane: status item installed (image=%@, title=%@)",
              button.image == nil ? "nil" : "set", button.title)
        rebuildMenu()
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem?.button else { return }
        applyButtonAppearance(button)
        rebuildMenu()
    }

    private func applyButtonAppearance(_ button: NSStatusBarButton) {
        let symbolName = "rectangle.split.2x2"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Pane") {
            image.isTemplate = true
            button.image = image
            button.title = hasPermission ? "" : " ⚠︎"
        } else {
            // Fallback if the SF symbol can't be resolved — guarantees a visible item.
            button.image = nil
            button.title = hasPermission ? "▦" : "▦ ⚠︎"
        }
        button.imagePosition = .imageLeading
        button.toolTip = hasPermission
            ? "Pane"
            : "Pane — needs Accessibility permission"
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if !hasPermission {
            let warn = NSMenuItem(
                title: "⚠︎ Accessibility permission required",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            warn.target = self
            menu.addItem(warn)
            let open = NSMenuItem(
                title: "Open Accessibility Settings…",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            open.target = self
            menu.addItem(open)
            menu.addItem(.separator())
        }

        addZoneItem(menu, "Left Half",     .leftHalf)
        addZoneItem(menu, "Right Half",    .rightHalf)
        addZoneItem(menu, "Maximize",      .maximize)
        menu.addItem(.separator())
        addZoneItem(menu, "Top Half",      .topHalf)
        addZoneItem(menu, "Bottom Half",   .bottomHalf)
        menu.addItem(.separator())
        addZoneItem(menu, "Top Left",      .topLeft)
        addZoneItem(menu, "Top Right",     .topRight)
        addZoneItem(menu, "Bottom Left",   .bottomLeft)
        addZoneItem(menu, "Bottom Right",  .bottomRight)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let about = NSMenuItem(title: "About Pane", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem(
            title: "Quit Pane",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }

    private func addZoneItem(_ menu: NSMenu, _ title: String, _ zone: SnapZone) {
        let binding = HotkeyStore.shared.binding(for: zone)
        let item = NSMenuItem(
            title: title,
            action: #selector(menuSnap(_:)),
            keyEquivalent: binding?.menuKeyEquivalent ?? ""
        )
        item.keyEquivalentModifierMask = binding?.modifierFlags ?? []
        item.representedObject = zone.rawValue
        item.target = self
        if !hasPermission { item.isEnabled = false }
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func menuSnap(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let zone = SnapZone(rawValue: raw) else { return }
        zone.apply()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.present()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Pane"
        alert.informativeText = """
        A minimal window-snapping utility for macOS.

        • Drag a window to the top of the screen to reveal the snap layout picker.
        • Use ⌃⌥ + arrow / U I J K / O L for direct snapping.
        """
        alert.runModal()
    }

    // MARK: - Permission polling

    private func recheckPermission() {
        let trusted = AXIsProcessTrusted()
        if trusted != hasPermission {
            hasPermission = trusted
            NSLog("Pane: accessibility permission changed → %d", trusted ? 1 : 0)
            updateStatusItemAppearance()
            startMonitorsIfPossible()
        }
    }

    private func startMonitorsIfPossible() {
        guard hasPermission else { return }
        if dragMonitor == nil {
            let m = DragMonitor()
            m.start()
            dragMonitor = m
            NSLog("Pane: drag monitor started")
        }
        if hotkeyManager == nil {
            let h = HotkeyManager()
            h.register()
            hotkeyManager = h
            NSLog("Pane: hotkeys registered")
        }
    }
}
