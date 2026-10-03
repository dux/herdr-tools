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
    private var panel: NSPanel?
    private var content: BarHostingView?
    private var launchTask: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var focusHideTask: Task<Void, Never>?
    private var tooltipTask: Task<Void, Never>?
    private var pendingTooltip: ClosedRange<CGFloat>?
    private let tooltip = BarTooltip()
    private var rightClickMonitor: Any?
    private var appEditor: AppEditorWindow?
    private var appManager: AppManagerWindow?
    private var focusWindow: FocusAppWindow?
    private var barFraction = UserDefaults.standard.object(forKey: "barOriginFraction") as? Double
    private var screenID = (UserDefaults.standard.object(forKey: "barScreenID") as? NSNumber)?.uint32Value

    init(launcher: AppLauncher, apps: AppStore, focus: FocusWatcher) {
        self.launcher = launcher
        self.apps = apps
        self.focus = focus
    }

    func show() {
        guard let screen = currentScreen() else { return }
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
        content.onHover = { [weak self] x in self?.hover(x) }
        panel.contentView = content
        self.content = content
        self.panel = panel
        panel.orderFrontRegardless()
        installRightClickMonitor()
        observeMessages()
        observeLayout()
        focus.onChange = { [weak self] in self?.applyFocus() }
        applyFocus()
    }

    func updateScreen() {
        guard let screen = currentScreen() else { return }
        let layout = layout(screen: screen, width: contentMetrics(screen: screen))
        content?.rootView = makeView()
        if peekTask == nil { panel?.setFrame(layout.bar, display: true) }
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
                try? await Task.sleep(for: .seconds(2))
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
        BarView(launcher: launcher, apps: apps, focus: focus,
                copyFolder: { [weak self] in self?.copyFolder() },
                addApp: { [weak self] in self?.addCustomApp() },
                manageApps: { [weak self] in self?.showAppManager() },
                switchDisplay: { [weak self] in self?.switchDisplay() },
                chooseFocusApp: { [weak self] in self?.chooseFocusApp() },
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

    // Mirrors BarView's HStack: 8 pt padding, 18 pt Herdr icon, 24 pt buttons, 6 pt spacing.
    private static let herdrIcon: ClosedRange<CGFloat> = 8...26
    private static let copyButton: ClosedRange<CGFloat> = 32...56
    private static let appsStart: CGFloat = 62
    private static let buttonWidth: CGFloat = 24
    private static let spacing: CGFloat = 6

    private func customAppsRange() -> ClosedRange<CGFloat>? {
        let count = apps.apps.count
        guard count > 0 else { return nil }
        let start = Self.appsStart
        return start...(start + CGFloat(count) * Self.buttonWidth + CGFloat(count - 1) * Self.spacing)
    }

    /// Hit ranges extend half the spacing to each side so sliding across icons never hits a gap.
    private func tooltipItem(at x: CGFloat) -> (text: String, range: ClosedRange<CGFloat>)? {
        let pad = Self.spacing / 2
        if x < Self.herdrIcon.upperBound + pad { return ("Drag to move", Self.herdrIcon) }
        if x < Self.copyButton.upperBound + pad { return ("Copy focused folder path", Self.copyButton) }
        let step = Self.buttonWidth + Self.spacing
        let index = Int(((x - Self.appsStart + pad) / step).rounded(.down))
        guard apps.apps.indices.contains(index) else { return nil }
        let minX = Self.appsStart + CGFloat(index) * step
        return (apps.apps[index].name, minX...(minX + Self.buttonWidth))
    }

    private func hover(_ x: CGFloat?) {
        guard let x, peekTask == nil, let item = tooltipItem(at: x) else { hideTooltip(); return }
        if tooltip.isVisible { showTooltip(item); return }
        // Keep the pending timer while the mouse stays on the same icon.
        guard item.range != pendingTooltip else { return }
        tooltipTask?.cancel()
        pendingTooltip = item.range
        tooltipTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.pendingTooltip = nil
            self.showTooltip(item)
        }
    }

    private func showTooltip(_ item: (text: String, range: ClosedRange<CGFloat>)) {
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
        if let barFraction { UserDefaults.standard.set(barFraction, forKey: "barOriginFraction") }
        if let screen = panel?.screen {
            screenID = screen.displayID
            if let screenID { UserDefaults.standard.set(Int(screenID), forKey: "barScreenID") }
        }
    }

    private func contentMetrics(screen: NSScreen) -> CGFloat {
        let controls = 92 + CGFloat(apps.apps.count) * 30
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
