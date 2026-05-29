import AppKit
import Carbon.HIToolbox
import Combine

// Carbon hotkey callbacks are `@convention(c)` and can't capture context,
// so we route through a process-global table keyed by hotkey ID.
nonisolated(unsafe) private var hotkeyMap: [UInt32: SnapZone] = [:]

private let hotkeyCallback: EventHandlerUPP = { _, eventRef, _ in
    guard let eventRef else { return OSStatus(eventNotHandledErr) }
    var hkID = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hkID
    )
    guard status == noErr, let zone = hotkeyMap[hkID.id] else {
        return OSStatus(eventNotHandledErr)
    }
    DispatchQueue.main.async { zone.apply() }
    return noErr
}

final class HotkeyManager {
    private var refs: [EventHotKeyRef] = []
    private var handlerInstalled = false
    private var cancellable: AnyCancellable?
    private let signature: OSType = 0x5041_4E45  // 'PANE'

    func register() {
        installHandler()
        applyCurrent()
        // Re-register whenever stored bindings change.
        cancellable = HotkeyStore.shared.$bindings
            .dropFirst()
            .sink { [weak self] _ in self?.applyCurrent() }
    }

    deinit {
        unregisterAll()
    }

    private func applyCurrent() {
        unregisterAll()
        var id: UInt32 = 1
        for zone in SnapZone.allCases {
            guard let binding = HotkeyStore.shared.binding(for: zone) else {
                id += 1
                continue
            }
            bind(zone, binding: binding, id: id)
            id += 1
        }
    }

    private func unregisterAll() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        hotkeyMap.removeAll()
    }

    private func bind(_ zone: SnapZone, binding: HotkeyBinding, id: UInt32) {
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            binding.keyCode, binding.carbonMods, hkID,
            GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr, let ref {
            refs.append(ref)
            hotkeyMap[id] = zone
        } else {
            NSLog("Pane: hotkey register failed for \(zone.rawValue) status=\(status)")
        }
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), hotkeyCallback, 1, &spec, nil, nil)
        handlerInstalled = true
    }
}
