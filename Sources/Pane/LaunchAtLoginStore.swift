import AppKit
import Combine
import ServiceManagement

/// Wraps `SMAppService.mainApp` so the rest of the app can treat
/// "launch at login" as a simple observable Bool. Apple's API is the
/// recommended replacement for the old SMLoginItemSetEnabled / helper-
/// bundle approach; works on macOS 13+ with no extra entitlement.
final class LaunchAtLoginStore: ObservableObject {
    static let shared = LaunchAtLoginStore()

    @Published var enabled: Bool {
        didSet { apply() }
    }

    private init() {
        enabled = (SMAppService.mainApp.status == .enabled)
    }

    /// Pulls the latest state from the system. Useful if the user toggled
    /// the login item in System Settings while Pane was running.
    func refresh() {
        let live = (SMAppService.mainApp.status == .enabled)
        if live != enabled { enabled = live }
    }

    private func apply() {
        let service = SMAppService.mainApp
        do {
            switch (enabled, service.status) {
            case (true, .enabled), (false, .notRegistered), (false, .notFound):
                return // already in the desired state
            case (true, _):
                try service.register()
            case (false, _):
                try service.unregister()
            }
        } catch {
            // The system rejected the change (e.g. user removed Pane from
            // login items in System Settings and our subsequent register
            // requires approval). Re-sync the UI to whatever the OS now
            // reports so the toggle doesn't lie.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let live = (SMAppService.mainApp.status == .enabled)
                if live != self.enabled { self.enabled = live }
            }
        }
    }
}
