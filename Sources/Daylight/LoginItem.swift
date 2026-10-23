import AppKit
import Combine
import ServiceManagement

@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var needsApproval = false
    @Published private(set) var message: String?
    private let service = SMAppService.mainApp

    init() { refresh() }

    func refresh() {
        enabled = service.status == .enabled
        needsApproval = service.status == .requiresApproval
        if enabled { message = nil }
    }

    func setEnabled(_ value: Bool) {
        UserDefaults.standard.set(true, forKey: "Daylight.LoginItemConfigured.v2")
        do {
            if value { try service.register() } else { try service.unregister() }
            message = nil
        } catch {
            message = value ? "Couldn’t enable launch at login. Keep Daylight in Applications and try again." : "Couldn’t change the login item. Try again in System Settings."
        }
        refresh()
    }

    func enableForInstalledAppIfNeeded(isTestProfile: Bool) {
        let preference = "Daylight.LoginItemConfigured.v2"
        guard !isTestProfile,
              Bundle.main.bundleURL.deletingLastPathComponent().lastPathComponent == "Applications",
              !UserDefaults.standard.bool(forKey: preference) else { return }
        if !enabled && !needsApproval { setEnabled(true) }
        // Do not re-enable a login item that the user subsequently disables.
        if enabled || needsApproval { UserDefaults.standard.set(true, forKey: preference) }
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
