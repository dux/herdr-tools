import AppKit
import QuartzCore
import SwiftUI
import PastirCore

@MainActor final class BarHostingView: NSHostingView<BarView> {
    var onRightClick: ((NSEvent) -> Bool)?
    var onIconDrag: ((CGFloat) -> Void)?
    var onIconDragEnd: (() -> Void)?
    private var draggingIcon = false
    private let iconHandleWidth: CGFloat = 32

    override func rightMouseDown(with event: NSEvent) {
        if onRightClick?(event) == true { return }
        super.rightMouseDown(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if convert(event.locationInWindow, from: nil).x < iconHandleWidth {
            draggingIcon = true
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if draggingIcon { onIconDrag?(event.deltaX); return }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if draggingIcon {
            draggingIcon = false
            onIconDragEnd?()
            return
        }
        super.mouseUp(with: event)
    }
}

@MainActor final class BarController {
    private let launcher: AppLauncher
    private let apps: AppStore
    private var panel: NSPanel?
    private var content: BarHostingView?
    private var launchTask: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var rightClickMonitor: Any?
    private var appEditor: AppEditorWindow?
    private var appManager: AppManagerWindow?
    private var barFraction = UserDefaults.standard.object(forKey: "barOriginFraction") as? Double

    init(launcher: AppLauncher, apps: AppStore) {
        self.launcher = launcher
        self.apps = apps
    }

    func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let layout = layout(screen: screen, width: contentMetrics(screen: screen))
        let panel = NSPanel(contentRect: layout.bar,
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.acceptsMouseMovedEvents = true
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let content = BarHostingView(rootView: makeView())
        content.sizingOptions = []
        content.onRightClick = { [weak self] event in self?.handleRightClick(event) ?? false }
        content.onIconDrag = { [weak self] delta in self?.dragIcon(by: delta) }
        content.onIconDragEnd = { [weak self] in self?.saveBarFraction() }
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
        let layout = layout(screen: screen, width: contentMetrics(screen: screen))
        content?.rootView = makeView()
        if peekTask == nil { panel?.setFrame(layout.bar, display: true) }
    }

    func stop() {
        launchTask?.cancel()
        peekTask?.cancel()
        if let rightClickMonitor { NSEvent.removeMonitor(rightClickMonitor) }
        rightClickMonitor = nil
    }

    private func launchCustom(_ app: CustomApp) {
        guard launcher.launching == nil else { return }
        launchTask = Task { await launcher.open(app) }
    }

    private func copyFolder() {
        Task { await launcher.copyFocusedFolder() }
    }

    func addCustomApp() { presentAppEditor(existing: nil) }

    private func editCustomApp(_ app: CustomApp) { presentAppEditor(existing: app) }

    private func showAppManager() {
        appManager?.close()
        appManager = AppManagerWindow(
            apps: apps,
            add: { [weak self] in self?.addCustomApp() },
            edit: { [weak self] app in self?.editCustomApp(app) },
            onClose: { [weak self] in self?.appManager = nil })
        appManager?.show()
    }

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

    private func makeView() -> BarView {
        BarView(launcher: launcher, apps: apps,
                copyFolder: { [weak self] in self?.copyFolder() },
                addApp: { [weak self] in self?.addCustomApp() },
                manageApps: { [weak self] in self?.showAppManager() },
                editApp: { [weak self] app in self?.editCustomApp(app) },
                removeApp: { [weak self] app in self?.apps.remove(app.id) },
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
        let start: CGFloat = 8 + 18 + 6 + 24 + 6
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
        let originX = barFraction.map { CGFloat($0) * screen.frame.width + screen.frame.minX }
        return BarLayout(screenFrame: screen.frame, contentWidth: width,
                         topArea: topArea(screen: screen), originX: originX)
    }

    private func dragIcon(by delta: CGFloat) {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        let area = topArea(screen: screen)
        let maxX = max(area.minX, area.maxX - panel.frame.width)
        let x = min(max(panel.frame.origin.x + delta, area.minX), maxX)
        panel.setFrameOrigin(NSPoint(x: x, y: panel.frame.origin.y))
        barFraction = Double((x - screen.frame.minX) / screen.frame.width)
    }

    private func saveBarFraction() {
        guard let barFraction else { return }
        UserDefaults.standard.set(barFraction, forKey: "barOriginFraction")
    }

    private func contentMetrics(screen: NSScreen) -> CGFloat {
        let controls = 98 + CGFloat(apps.apps.count) * 30
        return min(controls, min(800, topArea(screen: screen).width - 16))
    }

    private func observeLayout() {
        withObservationTracking {
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
            _ = launcher.message
            _ = apps.message
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let message = self.launcher.message ?? self.apps.message
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
