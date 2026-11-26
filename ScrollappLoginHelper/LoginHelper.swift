import AppKit

@main
struct LoginHelper {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = LoginHelperDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
private final class LoginHelperDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 13.0, *) { return }

        // The login item lives in Scrollapp.app/Contents/Library/LoginItems.
        let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard let appID = Bundle(url: appURL)?.bundleIdentifier,
              NSRunningApplication.runningApplications(withBundleIdentifier: appID).isEmpty else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.arguments = ["--launch-at-login"]
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    }
}
