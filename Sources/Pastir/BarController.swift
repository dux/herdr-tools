import AppKit
import SwiftUI
import PastirCore

@MainActor final class BarController {
    private let projects: ProjectStore
    private let launcher: AppLauncher
    private var panel: NSPanel?
    private var content: NSHostingView<BarView>?
    private var launchTask: Task<Void, Never>?

    init(projects: ProjectStore, launcher: AppLauncher) {
        self.projects = projects
        self.launcher = launcher
    }

    func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let metrics = contentMetrics(screen: screen)
        let layout = layout(screen: screen, width: metrics.width)
        let panel = NSPanel(contentRect: layout.bar,
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let content = NSHostingView(rootView: makeView(projectWidth: metrics.projects))
        content.sizingOptions = []
        panel.contentView = content
        self.content = content
        self.panel = panel
        panel.orderFrontRegardless()
        observeMessages()
        observeLayout()
    }

    func updateScreen() {
        guard let screen = panel?.screen ?? NSScreen.main ?? NSScreen.screens.first,
              let primary = NSScreen.screens.first else { return }
        let metrics = contentMetrics(screen: screen)
        let layout = layout(screen: screen, width: metrics.width)
        content?.rootView = makeView(projectWidth: metrics.projects)
        panel?.setFrame(layout.bar, display: true)
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
