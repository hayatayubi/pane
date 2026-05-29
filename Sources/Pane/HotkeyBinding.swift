import AppKit
import Carbon.HIToolbox
import Combine

struct HotkeyBinding: Codable, Equatable, Hashable {
    var keyCode: UInt32       // Carbon kVK_… value
    var carbonMods: UInt32    // controlKey | optionKey | shiftKey | cmdKey
    var displayChar: String   // user-visible key glyph, e.g. "U" or "←"

    /// Returns the modifier flags suitable for an NSMenuItem keyEquivalent.
    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonMods & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbonMods & UInt32(optionKey)  != 0 { flags.insert(.option)  }
        if carbonMods & UInt32(shiftKey)   != 0 { flags.insert(.shift)   }
        if carbonMods & UInt32(cmdKey)     != 0 { flags.insert(.command) }
        return flags
    }

    /// String like "⌃⌥U" / "⌃⌥←" for menus and labels.
    var displayString: String {
        var s = ""
        if carbonMods & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonMods & UInt32(optionKey)  != 0 { s += "⌥" }
        if carbonMods & UInt32(shiftKey)   != 0 { s += "⇧" }
        if carbonMods & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += displayChar
        return s
    }

    /// The lowercase character (or empty) usable as an NSMenuItem.keyEquivalent.
    /// Returns "" for special keys we can't easily express in that property —
    /// the actual hotkey dispatch still works via Carbon RegisterEventHotKey.
    var menuKeyEquivalent: String {
        switch keyCode {
        case UInt32(kVK_LeftArrow):  return String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!))
        case UInt32(kVK_RightArrow): return String(Character(UnicodeScalar(NSRightArrowFunctionKey)!))
        case UInt32(kVK_UpArrow):    return String(Character(UnicodeScalar(NSUpArrowFunctionKey)!))
        case UInt32(kVK_DownArrow):  return String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))
        default:
            return displayChar.lowercased()
        }
    }

    /// Build from an NSEvent key-down captured by the recorder.
    static func from(event: NSEvent) -> HotkeyBinding? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey)  }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey)   }
        if flags.contains(.command) { carbon |= UInt32(cmdKey)     }
        // Require at least one modifier so we don't capture bare letters.
        guard carbon != 0 else { return nil }

        let kc = UInt32(event.keyCode)
        let glyph = Self.displayChar(forKeyCode: kc, event: event)
        return HotkeyBinding(keyCode: kc, carbonMods: carbon, displayChar: glyph)
    }

    private static func displayChar(forKeyCode kc: UInt32, event: NSEvent) -> String {
        switch Int(kc) {
        case kVK_LeftArrow:  return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow:    return "↑"
        case kVK_DownArrow:  return "↓"
        case kVK_Return:     return "⏎"
        case kVK_Tab:        return "⇥"
        case kVK_Space:      return "␣"
        case kVK_Escape:     return "⎋"
        case kVK_Delete:     return "⌫"
        default:
            if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                return chars.uppercased()
            }
            return "?"
        }
    }
}

final class HotkeyStore: ObservableObject {
    static let shared = HotkeyStore()
    private static let defaultsKey = "Pane.hotkeyBindings.v1"

    @Published private(set) var bindings: [SnapZone: HotkeyBinding] = [:]

    private init() {
        load()
    }

    func binding(for zone: SnapZone) -> HotkeyBinding? {
        bindings[zone]
    }

    func set(_ binding: HotkeyBinding?, for zone: SnapZone) {
        if let binding {
            bindings[zone] = binding
        } else {
            bindings.removeValue(forKey: zone)
        }
        save()
    }

    func resetToDefaults() {
        bindings = Self.factoryDefaults
        save()
    }

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([String: HotkeyBinding].self, from: data) {
            var out: [SnapZone: HotkeyBinding] = [:]
            for (k, v) in decoded {
                if let zone = SnapZone(rawValue: k) { out[zone] = v }
            }
            bindings = out
        } else {
            bindings = Self.factoryDefaults
            save()
        }
    }

    private func save() {
        let encoded = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    static let factoryDefaults: [SnapZone: HotkeyBinding] = {
        let ctrlOpt = UInt32(controlKey | optionKey)
        return [
            .leftHalf:    .init(keyCode: UInt32(kVK_LeftArrow),  carbonMods: ctrlOpt, displayChar: "←"),
            .rightHalf:   .init(keyCode: UInt32(kVK_RightArrow), carbonMods: ctrlOpt, displayChar: "→"),
            .maximize:    .init(keyCode: UInt32(kVK_UpArrow),    carbonMods: ctrlOpt, displayChar: "↑"),
            .topHalf:     .init(keyCode: UInt32(kVK_ANSI_O),     carbonMods: ctrlOpt, displayChar: "O"),
            .bottomHalf:  .init(keyCode: UInt32(kVK_ANSI_L),     carbonMods: ctrlOpt, displayChar: "L"),
            .topLeft:     .init(keyCode: UInt32(kVK_ANSI_U),     carbonMods: ctrlOpt, displayChar: "U"),
            .topRight:    .init(keyCode: UInt32(kVK_ANSI_I),     carbonMods: ctrlOpt, displayChar: "I"),
            .bottomLeft:  .init(keyCode: UInt32(kVK_ANSI_J),     carbonMods: ctrlOpt, displayChar: "J"),
            .bottomRight: .init(keyCode: UInt32(kVK_ANSI_K),     carbonMods: ctrlOpt, displayChar: "K"),
        ]
    }()
}
