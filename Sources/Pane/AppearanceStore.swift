import AppKit
import SwiftUI
import Combine

/// Holds visual preferences (currently just the snap-outline color).
/// Persists to UserDefaults; published changes trigger live re-render of
/// the overlay because views observe this directly.
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()
    private static let colorKey = "Pane.outlineColor.v1"

    @Published var outlineColor: Color {
        didSet { saveColor() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.colorKey),
           let stored = try? JSONDecoder().decode(StoredColor.self, from: data) {
            outlineColor = stored.swiftUIColor
        } else {
            outlineColor = Self.defaultOutlineColor
        }
    }

    func resetToDefaults() {
        outlineColor = Self.defaultOutlineColor
    }

    private func saveColor() {
        let stored = StoredColor(color: outlineColor)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.colorKey)
        }
    }

    /// A vivid blue close to the macOS default accent — used when no value
    /// has been stored yet, and as the "Reset" target.
    static let defaultOutlineColor = Color(red: 0.20, green: 0.55, blue: 1.00)
}

private struct StoredColor: Codable {
    let r: Double
    let g: Double
    let b: Double
    let a: Double

    init(color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.systemBlue
        var rf: CGFloat = 0, gf: CGFloat = 0, bf: CGFloat = 0, af: CGFloat = 0
        ns.getRed(&rf, green: &gf, blue: &bf, alpha: &af)
        r = Double(rf); g = Double(gf); b = Double(bf); a = Double(af)
    }

    var swiftUIColor: Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }
}
