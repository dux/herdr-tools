import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let apps: AppStore
    private let bar: BarController

    override init() {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ProjectBar")
        let apps = AppStore(file: CustomAppFile(url: directory.appendingPathComponent("apps.json")))
        let launcher = AppLauncher()
        self.apps = apps
        self.bar = BarController(launcher: launcher, apps: apps)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 350])
        if let iconURL = Bundle.main.url(forResource: "HerdrTools", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
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

    @objc private func screenChanged() { bar.updateScreen() }
}
