import AppKit
import SwiftUI
import PastirCore

@MainActor final class AppEditorWindow: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let onClose: () -> Void

    init(existing: CustomApp?, onSave: @escaping (CustomApp) -> Void, onClose: @escaping () -> Void) {
        self.onClose = onClose
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 540, height: 300),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        self.panel = panel
        super.init()
        panel.title = existing == nil ? "Add App" : "Edit App"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentViewController = NSHostingController(rootView: AppEditorView(
            existing: existing,
            onSave: { app in onSave(app); panel.close() },
            cancel: { panel.close() }))
    }

    func show() {
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() { panel.close() }

    func windowWillClose(_ notification: Notification) { onClose() }
}
