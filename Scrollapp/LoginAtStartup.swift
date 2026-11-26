import AppKit
import Carbon
import ServiceManagement

enum LoginAtStartup {
    private static let enabledKey = "launchAtLogin"
    private static let legacyRegistrationKey = "legacyLoginHelperRegistered"
    private static let helperID = "com.corinthians.Scrollapp.LoginHelper"

    static var wasLaunchedAtLogin: Bool {
        if ProcessInfo.processInfo.arguments.contains("--launch-at-login") { return true }
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    static var menuState: NSControl.StateValue {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled: return .on
            case .requiresApproval: return .mixed
            default: return .off
            }
        }
        return UserDefaults.standard.bool(forKey: legacyRegistrationKey) ? .on : .off
    }

    static func restoreRegistration() throws {
        let defaults = UserDefaults.standard
        let isLegacyRegistered = defaults.bool(forKey: legacyRegistrationKey)
        if #available(macOS 13.0, *) {
            guard isLegacyRegistered else { return }
            if menuState == .off && defaults.bool(forKey: enabledKey) { try SMAppService.mainApp.register() }
            if SMLoginItemSetEnabled(helperID as CFString, false) { defaults.removeObject(forKey: legacyRegistrationKey) }
        } else if !isLegacyRegistered && defaults.bool(forKey: enabledKey) {
            try setEnabled(true)
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } else {
            guard SMLoginItemSetEnabled(helperID as CFString, enabled) else { throw RegistrationError() }
            UserDefaults.standard.set(enabled, forKey: legacyRegistrationKey)
        }
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    private struct RegistrationError: LocalizedError {
        var errorDescription: String? { "macOS couldn't update Scrollapp’s login helper." }
    }
}
