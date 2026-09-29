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
    private var panel: NSPanel?
    private var content: BarHostingView?
    private var launchTask: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var rightClickMonitor: Any?
    private var projectStripWidth: CGFloat = 0
    private let projectStripOrigin: CGFloat = 32

    init(projects: ProjectStore, launcher: AppLauncher) {
        self.projects = projects
        self.launcher = launcher
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
        guard let screen = panel?.screen ?? NSScreen.main ?? NSScreen.screens.first,
              let primary = NSScreen.screens.first else { return }
        let metrics = contentMetrics(screen: screen)
        let layout = layout(screen: screen, width: metrics.width)
        projectStripWidth = metrics.projects
        content?.rootView = makeView(projectWidth: metrics.projects)
        if peekTask == nil { panel?.setFrame(layout.bar, display: true) }
        launcher.updateFrame(layout.accessibilityFrame(primaryScreenTop: primary.frame.maxY))
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
        launcher.stopWindowManagement()
    }

    private func launch(_ target: TargetApp) {
        guard launcher.launching == nil, let project = projects.selected,
              let screen = panel?.screen ?? NSScreen.main,
              let primary = NSScreen.screens.first else { return }
        let frame = layout(screen: screen, width: panel?.frame.width ?? 0)
            .accessibilityFrame(primaryScreenTop: primary.frame.maxY)
        launchTask = Task { await launcher.open(target, project: project, frame: frame) }
    }

    private func makeView(projectWidth: CGFloat) -> BarView {
        BarView(projects: projects, launcher: launcher, projectStripWidth: projectWidth,
                addFolder: { [weak self] in self?.addFolder() },
                launch: { [weak self] target in self?.launch(target) })
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
        let overProjects = x >= projectStripOrigin && x <= projectStripOrigin + projectStripWidth
        guard !overProjects else { return false }
        peek()
        return true
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
        BarLayout(screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                  contentWidth: width, topArea: topArea(screen: screen))
    }

    private func contentMetrics(screen: NSScreen) -> (width: CGFloat, projects: CGFloat) {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let projectWidth: CGFloat
        if projects.projects.isEmpty {
            projectWidth = ceil(("Add a project" as NSString).size(withAttributes: [.font: font]).width)
        } else {
            projectWidth = projects.projects.reduce(0) { width, project in
                width + ceil((project.name as NSString).size(withAttributes: [.font: font]).width) + 32
            } + CGFloat(max(0, projects.projects.count - 1)) * 6
        }
        let controls: CGFloat = launcher.hasWindowAccess ? 191 : 217
        let maximum = min(800, topArea(screen: screen).width - 16)
        let stripWidth = max(0, min(projectWidth, maximum - controls))
        return (controls + stripWidth, stripWidth)
    }

    private func observeLayout() {
        withObservationTracking {
            _ = projects.projects
            _ = launcher.hasWindowAccess
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
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let message = self.projects.message ?? self.launcher.message
                self.projects.message = nil
                self.launcher.message = nil
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
