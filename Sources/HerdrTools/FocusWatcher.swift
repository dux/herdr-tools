import AppKit
import Observation

@MainActor @Observable final class FocusWatcher {
    private(set) var appID = UserDefaults.standard.string(forKey: "focusAppID")
    private(set) var appName = UserDefaults.standard.string(forKey: "focusAppName")
    private(set) var frontmostID: String?
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var observer: Any?

    /// Our own windows (editor, alerts) count as focused so the bar stays while they are up.
    var shouldShow: Bool {
        appID == nil || frontmostID == appID || frontmostID == Bundle.main.bundleIdentifier
    }

    func start() {
        frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                self?.frontmostID = id
                self?.onChange?()
            }
        }
    }

    /// nil turns the filter off and keeps the bar always visible.
    func select(_ app: InstalledApp?) {
        appID = app?.bundleID
        appName = appID == nil ? nil : app?.name
        UserDefaults.standard.set(appID, forKey: "focusAppID")
        UserDefaults.standard.set(appName, forKey: "focusAppName")
        onChange?()
    }
}
