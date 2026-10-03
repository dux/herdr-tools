import AppKit
import SwiftUI

@MainActor final class FocusAppWindow: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let onClose: () -> Void

    init(focus: FocusWatcher, onClose: @escaping () -> Void) {
        self.onClose = onClose
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 410),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        self.panel = panel
        super.init()
        panel.title = "Show Only When in Focus"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentViewController = NSHostingController(rootView: FocusAppView(
            select: { app in focus.select(app); panel.close() },
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

private struct FocusAppView: View {
    let select: (InstalledApp?) -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            InstalledAppPicker { select($0) }
            Divider()
            HStack {
                Button("Always show") { select(nil) }
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
    }
}
