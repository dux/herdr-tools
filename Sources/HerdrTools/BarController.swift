import AppKit
import QuartzCore
import SwiftUI
import HerdrToolsCore

@MainActor final class BarHostingView: NSHostingView<BarView> {
    var onRightClick: ((NSEvent) -> Bool)?
    var onIconDrag: ((CGFloat) -> Void)?
    var onIconDragEnd: (() -> Void)?
    /// Mouse x in view coordinates, nil when the mouse leaves or clicks.
    var onHover: ((CGFloat?) -> Void)?
    private var draggingIcon = false
    private var hoverArea: NSTrackingArea?
    private let iconHandleWidth: CGFloat = 32

    // .activeAlways because the bar is non-activating, so the app is usually inactive.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        onHover?(convert(event.locationInWindow, from: nil).x)
        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        if event.trackingArea === hoverArea { onHover?(nil) }
        super.mouseExited(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        onHover?(nil)
        if onRightClick?(event) == true { return }
        super.rightMouseDown(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onHover?(nil)
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
    private let focus: FocusWatcher
    private let sleep: SleepBlocker
    private var hits: [BarHit] = []
    private var naturalWidth: CGFloat = 0
    private var panel: NSPanel?
    private var content: BarHostingView?
    private var launchTask: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var focusHideTask: Task<Void, Never>?
    private var tooltipTask: Task<Void, Never>?
    private var pendingTooltip: BarHit?
    private let tooltip = BarTooltip()
    private var rightClickMonitor: Any?
    private var appEditor: AppEditorWindow?
    private var appManager: AppManagerWindow?
    private var focusWindow: FocusAppWindow?
    private var barFraction = UserDefaults.standard.object(forKey: "barOriginFraction") as? Double
    private var screenID = (UserDefaults.standard.object(forKey: "barScreenID") as? NSNumber)?.uint32Value

    init(launcher: AppLauncher, apps: AppStore, focus: FocusWatcher, sleep: SleepBlocker) {
        self.launcher = launcher
        self.apps = apps
        self.focus = focus
        self.sleep = sleep
    }

    func show() {
        guard let screen = currentScreen() else { return }
        let layout = layout(screen: screen, width: contentWidth(screen: screen))
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
        content.onHover = { [weak self] x in self?.hover(x) }
        panel.contentView = content
        self.content = content
        self.panel = panel
        panel.orderFrontRegardless()
        installRightClickMonitor()
        observeMessages()
        focus.onChange = { [weak self] in self?.applyFocus() }
        applyFocus()
    }

    func updateScreen() {
        guard let screen = currentScreen() else { return }
        content?.rootView = makeView()
        applyFrame(screen: screen)
    }

    private func applyFrame(screen: NSScreen) {
        guard peekTask == nil else { return }
        panel?.setFrame(layout(screen: screen, width: contentWidth(screen: screen)).bar, display: true)
    }

    private func resize(to width: CGFloat) {
        naturalWidth = width
        if let screen = currentScreen() { applyFrame(screen: screen) }
    }

    func switchDisplay() {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }
        let current = currentScreen()
        let index = screens.firstIndex { $0.displayID == current?.displayID } ?? 0
        let next = screens[(index + 1) % screens.count]
        screenID = next.displayID
        if let screenID { UserDefaults.standard.set(Int(screenID), forKey: "barScreenID") }
        updateScreen()
    }

    private func currentScreen() -> NSScreen? {
        if let screenID, let match = NSScreen.screens.first(where: { $0.displayID == screenID }) {
            return match
        }
        return panel?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    func stop() {
        launchTask?.cancel()
        peekTask?.cancel()
        focusHideTask?.cancel()
        hideTooltip()
        if let rightClickMonitor { NSEvent.removeMonitor(rightClickMonitor) }
        rightClickMonitor = nil
    }

    private func launchCustom(_ app: CustomApp) {
        guard launcher.launching == nil else { return }
        // Make the bar's display the active one so the app opens here.
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
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

    private func chooseFocusApp() {
        focusWindow?.close()
        focusWindow = FocusAppWindow(focus: focus, onClose: { [weak self] in self?.focusWindow = nil })
        focusWindow?.show()
    }

    private func applyFocus() {
        guard let panel else { return }
        if focus.shouldShow {
            focusHideTask?.cancel()
            focusHideTask = nil
            // Zero-duration group replaces an in-flight fade-out instead of racing it.
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                panel.animator().alphaValue = 1
            }
            panel.orderFrontRegardless()
        } else if focusHideTask == nil {
            focusHideTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.5))
                guard let self, !Task.isCancelled, let panel = self.panel else { return }
                self.hideTooltip()
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    panel.animator().alphaValue = 0
                } completionHandler: { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self, !self.focus.shouldShow else { return }
                        self.panel?.orderOut(nil)
                    }
                }
            }
        }
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
        BarView(launcher: launcher, apps: apps, focus: focus, sleep: sleep,
                copyFolder: { [weak self] in self?.copyFolder() },
                addApp: { [weak self] in self?.addCustomApp() },
                manageApps: { [weak self] in self?.showAppManager() },
                switchDisplay: { [weak self] in self?.switchDisplay() },
                chooseFocusApp: { [weak self] in self?.chooseFocusApp() },
                editApp: { [weak self] app in self?.editCustomApp(app) },
                removeApp: { [weak self] app in self?.apps.remove(app.id) },
                launchCustom: { [weak self] app in self?.launchCustom(app) },
                reportHits: { [weak self] hits in self?.hits = hits },
                reportWidth: { [weak self] width in self?.resize(to: width) })
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
        // Items with their own context menu (custom apps) handle the click themselves.
        if hits.contains(where: { $0.hasContextMenu && $0.range.contains(x) }) { return false }
        peek()
        return true
    }

    /// Hit ranges extend half the spacing to each side so sliding across icons never hits a gap.
    private func tooltipItem(at x: CGFloat) -> BarHit? {
        let pad = BarView.spacing / 2
        return hits.first { ($0.range.lowerBound - pad)...($0.range.upperBound + pad) ~= x }
    }

    private func hover(_ x: CGFloat?) {
        guard let x, peekTask == nil, let item = tooltipItem(at: x) else { hideTooltip(); return }
        if tooltip.isVisible { showTooltip(item); return }
        // Keep the pending timer while the mouse stays on the same icon.
        guard item != pendingTooltip else { return }
        tooltipTask?.cancel()
        pendingTooltip = item
        tooltipTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.pendingTooltip = nil
            self.showTooltip(item)
        }
    }

    private func showTooltip(_ item: BarHit) {
        guard let panel, let screen = panel.screen else { return }
        let anchor = CGRect(x: panel.frame.minX + item.range.lowerBound, y: panel.frame.minY,
                            width: item.range.upperBound - item.range.lowerBound, height: 0)
        tooltip.show(item.text, below: anchor, on: screen)
    }

    private func hideTooltip() {
        tooltipTask?.cancel()
        pendingTooltip = nil
        tooltip.hide()
    }

    private func peek() {
        guard peekTask == nil, let panel else { return }
        hideTooltip()
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        var hidden = layout(screen: screen, width: panel.frame.width).bar
        hidden.origin.y = screen.frame.maxY
        animate(panel, to: hidden, alpha: 0)
        peekTask = Task { @MainActor [weak self] in
            defer { self?.peekTask = nil }
            try? await Task.sleep(for: .seconds(5))
            guard let self, !Task.isCancelled, let panel = self.panel else { return }
            let target = panel.screen ?? screen
            let restored = self.layout(screen: target, width: self.contentWidth(screen: target)).bar
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
        if let barFraction { UserDefaults.standard.set(barFraction, forKey: "barOriginFraction") }
        if let screen = panel?.screen {
            screenID = screen.displayID
            if let screenID { UserDefaults.standard.set(Int(screenID), forKey: "barScreenID") }
        }
    }

    private func contentWidth(screen: NSScreen) -> CGFloat {
        min(naturalWidth, min(800, topArea(screen: screen).width - 16))
    }

    private func observeMessages() {
        withObservationTracking {
            _ = launcher.message
            _ = apps.message
            _ = sleep.message
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let message = self.launcher.message ?? self.apps.message ?? self.sleep.message
                self.launcher.message = nil
                self.apps.message = nil
                self.sleep.message = nil
                self.observeMessages()
                if let message {
                    let alert = NSAlert()
                    alert.messageText = "Herdr Tools"
                    alert.informativeText = message
                    NSApp.activate()
                    alert.runModal()
                }
            }
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
