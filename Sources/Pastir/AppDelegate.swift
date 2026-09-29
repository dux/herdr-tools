import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let projects: ProjectStore
    private let launcher: AppLauncher
    private let bar: BarController
    private var statusItem: NSStatusItem?

    override init() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ProjectBar/projects.json")
        let projects = ProjectStore(file: ProjectFile(url: url))
        let launcher = AppLauncher(placer: WindowPlacer())
        self.projects = projects
        self.launcher = launcher
        self.bar = BarController(projects: projects, launcher: launcher)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        menu.addItem(withTitle: "Add project folder...", action: #selector(addProject), keyEquivalent: "")
        menu.addItem(withTitle: "Enable Window Control", action: #selector(enableAccess), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Pastir", action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items { menuItem.target = self }
        item.menu = menu
        statusItem = item
        bar.show()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshAccess),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        Task { await projects.load() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            if await projects.flush() {
                bar.stop()
                sender.reply(toApplicationShouldTerminate: true)
            } else {
                sender.reply(toApplicationShouldTerminate: false)
            }
        }
        return .terminateLater
    }

    @objc private func addProject() { bar.addFolder() }
    @objc private func enableAccess() { launcher.enableAccess() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func screenChanged() { bar.updateScreen() }
    @objc private func refreshAccess() { launcher.refreshAccess() }
}
