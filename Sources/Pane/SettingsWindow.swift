import AppKit
import SwiftUI
import Carbon.HIToolbox

// MARK: - NSWindowController wrapper

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 540),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pane Settings"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func present() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
}

// Re-hide the Dock icon when the settings window closes, so we stay a
// menu-bar-only app the rest of the time.
extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Settings view

private struct SettingsView: View {
    @ObservedObject private var store = HotkeyStore.shared

    private let rows: [(SnapZone, String)] = [
        (.maximize,    "Maximize"),
        (.leftHalf,    "Left Half"),
        (.rightHalf,   "Right Half"),
        (.topHalf,     "Top Half"),
        (.bottomHalf,  "Bottom Half"),
        (.topLeft,     "Top Left"),
        (.topRight,    "Top Right"),
        (.bottomLeft,  "Bottom Left"),
        (.bottomRight, "Bottom Right"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { i in
                        let (zone, title) = rows[i]
                        BindingRow(zone: zone, title: title)
                        if i < rows.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }

            footer
        }
        .frame(minWidth: 480, minHeight: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Keyboard Shortcuts")
                .font(.system(size: 18, weight: .semibold))
            Text("Click a shortcut to record a new key combination. Press Esc to cancel, ⌫ to clear.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        HStack {
            Button("Reset to Defaults") { store.resetToDefaults() }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .top)
    }
}

private struct BindingRow: View {
    let zone: SnapZone
    let title: String
    @ObservedObject private var store = HotkeyStore.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: zone.symbolName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 13))
            Spacer()
            HotkeyRecorderView(
                binding: store.binding(for: zone),
                onChange: { newBinding in store.set(newBinding, for: zone) }
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

// MARK: - Hotkey recorder

private struct HotkeyRecorderView: View {
    let binding: HotkeyBinding?
    let onChange: (HotkeyBinding?) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(labelColor)
                    .frame(minWidth: 60)
                if isRecording {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isRecording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isRecording ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }

    private var label: String {
        if isRecording { return "Press keys…" }
        return binding?.displayString ?? "—"
    }

    private var labelColor: Color {
        if isRecording { return .accentColor }
        return binding == nil ? .secondary : .primary
    }

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            guard isRecording else { return event }
            if event.type == .keyDown {
                // Esc cancels, ⌫ clears.
                if event.keyCode == UInt16(kVK_Escape) {
                    stopRecording()
                    return nil
                }
                if event.keyCode == UInt16(kVK_Delete) {
                    onChange(nil)
                    stopRecording()
                    return nil
                }
                if let captured = HotkeyBinding.from(event: event) {
                    onChange(captured)
                    stopRecording()
                    return nil
                }
            }
            return event
        }
    }

    private func stopRecording() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        isRecording = false
    }
}
