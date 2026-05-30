import Foundation
import Combine
import CoreGraphics

/// How aggressive the drag-to-snap trigger zones are. The cursor only
/// has to get within `edgeProximity` of a screen edge for the half-screen
/// outline to appear, and within `cornerReach` of an adjacent edge for the
/// corner quarter-screen zones to take over.
enum SnapSensitivity: String, CaseIterable, Codable, Sendable {
    case low, medium, high

    var displayName: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    var edgeProximity: CGFloat {
        switch self {
        case .low:    return 90
        case .medium: return 170
        case .high:   return 260
        }
    }

    var cornerReach: CGFloat {
        switch self {
        case .low:    return 200
        case .medium: return 300
        case .high:   return 380
        }
    }
}

final class SensitivityStore: ObservableObject {
    static let shared = SensitivityStore()
    private static let key = "Pane.snapSensitivity.v1"

    @Published var sensitivity: SnapSensitivity {
        didSet { save() }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key),
           let stored = SnapSensitivity(rawValue: raw) {
            sensitivity = stored
        } else {
            sensitivity = .high
        }
    }

    func resetToDefaults() {
        sensitivity = .high
    }

    private func save() {
        UserDefaults.standard.set(sensitivity.rawValue, forKey: Self.key)
    }
}
