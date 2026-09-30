import AppKit
import QuartzCore
import SwiftUI
import PastirCore

@MainActor final class BarHostingView: NSHostingView<BarView> {
    var onRightClick: ((NSEvent) -> Bool)?

    override func rightMouseDown(with event: NSEvent) {
        if onRightClick?(event) == true { return }
        super.rightMouseDown(with: event)
    }
}

@MainActor final class BarController {
    private let projects: ProjectStore
    private let launcher: AppLauncher
    private let apps: AppStore
    private var panel: NSPanel?
    private var content: BarHostingView?
    private var launchTask: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var rightClickMonitor: Any?
    private var appEditor: AppEditorWindow?
    private var projectStripWidth: CGFloat = 0

    init(projects: ProjectStore, launcher: AppLauncher, apps: AppStore) {
        self.projects = projects
        self.launcher = launcher
        self.apps = apps
    }

    func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let metrics = contentMetrics(screen: screen)
        let layout = layout(screen: screen, width: metrics.width)
        projectStripWidth = metrics.projects
        let panel = NSPanel(contentRect: layout.bar,
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let content = BarHostingView(rootView: makeView(projectWidth: metrics.projects))
        content.sizingOptions = []
        content.onRightClick = { [weak self] event in self?.handleRightClick(event) ?? false }
        panel.contentView = content
        self.content = content
        self.panel = panel
        panel.orderFrontRegardless()
        installRightClickMonitor()
        observeMessages()
        observeLayout()
    }

    func updateScreen() {
        guard let screen = panel?.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let metrics = contentMetrics(screen: screen)
        let layout = layout(screen: screen, width: metrics.width)
        projectStripWidth = metrics.projects
        content?.rootView = makeView(projectWidth: metrics.projects)
        if peekTask == nil { panel?.setFrame(layout.bar, display: true) }
    }

    func addFolder() {
        let picker = NSOpenPanel()
        picker.title = "Add project folder"
        picker.prompt = "Add Project"
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.allowsMultipleSelection = true
        NSApp.activate()
        if picker.runModal() == .OK {
            for url in picker.urls { projects.add(url) }
        }
    }

    func stop() {
        launchTask?.cancel()
        peekTask?.cancel()
        if let rightClickMonitor { NSEvent.removeMonitor(rightClickMonitor) }
        rightClickMonitor = nil
    }

    private func launch(_ target: TargetApp) {
        guard launcher.launching == nil, let project = projects.selected else { return }
        launchTask = Task { await launcher.open(target, project: project) }
    }

    private func launchCustom(_ app: CustomApp) {
        guard launcher.launching == nil, let project = projects.selected else { return }
        launchTask = Task { await launcher.openCustom(app, project: project) }
    }

    func addCustomApp() { presentAppEditor(existing: nil) }

    private func editCustomApp(_ app: CustomApp) { presentAppEditor(existing: app) }

    private func presentAppEditor(existing: CustomApp?) {
        appEditor?.close()
        appEditor = AppEditorWindow(
            existing: existing,
            onSave: { [weak self] app in
                guard let self else { return }
                if existing == nil { self.apps.add(app) } else { self.apps.update(app) }
            },
            onClose: { [weak self] in self?.appEditor = nil })
        appEditor?.show()
    }

    private func makeView(projectWidth: CGFloat) -> BarView {
        BarView(projects: projects, launcher: launcher, apps: apps, projectStripWidth: projectWidth,
                addFolder: { [weak self] in self?.addFolder() },
                addApp: { [weak self] in self?.addCustomApp() },
                editApp: { [weak self] app in self?.editCustomApp(app) },
                removeApp: { [weak self] app in self?.apps.remove(app.id) },
                launch: { [weak self] target in self?.launch(target) },
                launchCustom: { [weak self] app in self?.launchCustom(app) })
    }

    private func installRightClickMonitor() {
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event in
            MainActor.assumeIsolated { _ = self?.handleRightClick(event) }
            return event
        }
    }

    private func handleRightClick(_ event: NSEvent) -> Bool {
        guard let content, event.window === panel else { return false }
        let x = content.convert(event.locationInWindow, from: nil).x
        if let customApps = customAppsRange(), customApps.contains(x) { return false }
        peek()
        return true
    }

    private func customAppsRange() -> ClosedRange<CGFloat>? {
        let count = apps.apps.count
        guard count > 0 else { return nil }
        let builtinEnd = 8 + 18 + 6 + projectStripWidth + 6 + 1 + 6 + (3 * 24 + 2 * 6)
        let start = builtinEnd + 6
        return start...(start + CGFloat(count) * 24 + CGFloat(count - 1) * 6)
    }

    private func peek() {
        guard peekTask == nil, let panel else { return }
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        var hidden = layout(screen: screen, width: panel.frame.width).bar
        hidden.origin.y = screen.frame.maxY
        animate(panel, to: hidden, alpha: 0)
        peekTask = Task { @MainActor [weak self] in
            defer { self?.peekTask = nil }
            try? await Task.sleep(for: .seconds(5))
            guard let self, !Task.isCancelled, let panel = self.panel else { return }
            let restored = self.layout(screen: panel.screen ?? screen, width: panel.frame.width).bar
            self.animate(panel, to: restored, alpha: 1)
        }
    }

    private func animate(_ panel: NSPanel, to frame: CGRect, alpha: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = alpha
        }
    }

    private func topArea(screen: NSScreen) -> CGRect {
        guard screen.safeAreaInsets.top > 0 else { return screen.frame }
        return [screen.auxiliaryTopLeftArea, screen.auxiliaryTopRightArea]
            .compactMap { $0 }.max { $0.width < $1.width } ?? screen.frame
    }

    private func layout(screen: NSScreen, width: CGFloat) -> BarLayout {
        BarLayout(screenFrame: screen.frame, contentWidth: width, topArea: topArea(screen: screen))
    }

    private func contentMetrics(screen: NSScreen) -> (width: CGFloat, projects: CGFloat) {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let name = projects.selected?.name ?? "Add a project"
        let projectWidth = ceil((name as NSString).size(withAttributes: [.font: font]).width) + 48
        let controls: CGFloat = 191 + CGFloat(apps.apps.count) * 30
        let maximum = min(800, topArea(screen: screen).width - 16)
        let stripWidth = max(0, min(projectWidth, maximum - controls))
        return (controls + stripWidth, stripWidth)
    }

    private func observeLayout() {
        withObservationTracking {
            _ = projects.projects
            _ = projects.selectedID
            _ = apps.apps
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateScreen()
                self.observeLayout()
            }
        }
    }

    private func observeMessages() {
        withObservationTracking {
            _ = projects.message
            _ = launcher.message
            _ = apps.message
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let message = self.projects.message ?? self.launcher.message ?? self.apps.message
                self.projects.message = nil
                self.launcher.message = nil
                self.apps.message = nil
                self.observeMessages()
                if let message {
                    let alert = NSAlert()
                    alert.messageText = "Pastir"
                    alert.informativeText = message
                    NSApp.activate()
                    alert.runModal()
                }
            }
        }
    }
}
