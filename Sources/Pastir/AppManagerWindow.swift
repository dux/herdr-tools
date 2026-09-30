import AppKit
import SwiftUI
import PastirCore

@MainActor final class AppManagerWindow: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let onClose: () -> Void

    init(apps: AppStore, add: @escaping () -> Void, edit: @escaping (CustomApp) -> Void,
         onClose: @escaping () -> Void) {
        self.onClose = onClose
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        self.panel = panel
        super.init()
        panel.title = "Applications"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentViewController = NSHostingController(rootView: AppManagerView(
            apps: apps,
            add: add,
            edit: edit,
            close: { panel.close() }))
    }

    func show() {
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() { panel.close() }

    func windowWillClose(_ notification: Notification) { onClose() }
}
