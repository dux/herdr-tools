import AppKit
import SwiftUI
import PastirCore

@MainActor enum AppEditorWindow {
    static func present(existing: CustomApp?, onSave: @escaping (CustomApp) -> Void) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = existing == nil ? "Add App" : "Edit App"
        let view = AppEditorView(existing: existing,
                                 onSave: { app in onSave(app); NSApp.stopModal(withCode: .OK) },
                                 cancel: { NSApp.stopModal(withCode: .cancel) })
        let controller = NSHostingController(rootView: view)
        window.contentViewController = controller
        controller.view.layoutSubtreeIfNeeded()
        window.setContentSize(controller.view.fittingSize)
        window.center()
        NSApp.activate()
        NSApp.runModal(for: window)
        window.orderOut(nil)
    }
}
