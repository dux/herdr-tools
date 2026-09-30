import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let apps: AppStore
    private let launcher: AppLauncher
    private let bar: BarController
    private var statusItem: NSStatusItem?

    override init() {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ProjectBar")
        let apps = AppStore(file: CustomAppFile(url: directory.appendingPathComponent("apps.json")))
        let launcher = AppLauncher()
        self.apps = apps
        self.launcher = launcher
        self.bar = BarController(launcher: launcher, apps: apps)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 350])
        if let iconURL = Bundle.main.url(forResource: "Pastir", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let icon = NSApp.applicationIconImage.copy() as? NSImage {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            item.button?.image = icon
        }
        item.button?.toolTip = "Pastir"
        let menu = NSMenu()
        menu.addItem(withTitle: "Add application...", action: #selector(addApp), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Pastir", action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items { menuItem.target = self }
        item.menu = menu
        statusItem = item
        bar.show()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        Task { await apps.load() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            if await apps.flush() {
                bar.stop()
                sender.reply(toApplicationShouldTerminate: true)
            } else {
                sender.reply(toApplicationShouldTerminate: false)
            }
        }
        return .terminateLater
    }

    @objc private func addApp() { bar.addCustomApp() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func screenChanged() { bar.updateScreen() }
}
