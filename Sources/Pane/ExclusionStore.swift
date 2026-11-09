import AppKit
import ApplicationServices
import Combine
import Foundation

struct ExcludedApp: Codable, Equatable, Identifiable {
    var bundleID: String
    var name: String
    var blockDrag: Bool
    var blockShortcuts: Bool

    var id: String { bundleID }
}

final class ExclusionStore: ObservableObject {
    static let shared = ExclusionStore()
    private static let key = "Pane.excludedApps.v1"

    @Published private(set) var apps: [ExcludedApp] = []

    private init() {
        load()
    }

    // MARK: - Queries

    func isDragBlocked(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return apps.contains { $0.bundleID == bundleID && $0.blockDrag }
    }

    func isShortcutBlocked(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return apps.contains { $0.bundleID == bundleID && $0.blockShortcuts }
    }

    // MARK: - Mutations

    func add(bundleID: String, name: String) {
        if apps.contains(where: { $0.bundleID == bundleID }) { return }
        apps.append(ExcludedApp(
            bundleID: bundleID, name: name,
            blockDrag: true, blockShortcuts: true
        ))
        save()
    }

    func remove(bundleID: String) {
        apps.removeAll { $0.bundleID == bundleID }
        save()
    }

    func setBlockDrag(_ value: Bool, for bundleID: String) {
        guard let i = apps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        apps[i].blockDrag = value
        save()
    }

    func setBlockShortcuts(_ value: Bool, for bundleID: String) {
        guard let i = apps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        apps[i].blockShortcuts = value
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([ExcludedApp].self, from: data) else {
            apps = []
            return
        }
        apps = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

// MARK: - AX helpers

enum AXApp {
    /// Bundle identifier of the app that owns `window`, if resolvable.
    static func bundleID(of window: AXUIElement) -> String? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    /// Bundle identifier of the frontmost app (used for hotkey blocking).
    static func focusedBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
