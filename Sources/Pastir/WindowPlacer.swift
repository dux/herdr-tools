import AppKit
import ApplicationServices
import PastirCore

@MainActor final class WindowPlacer {
    var reportFailure: ((String) -> Void)?
    private var managedWindows: [ManagedWindow] = []
    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func place(app: NSRunningApplication, project: Project, target: TargetApp, frame: CGRect) async throws {
        guard isTrusted else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.5)
        // App launch completion precedes document-window creation.
        for _ in 0..<40 {
            try Task.checkCancellation()
            if let window = findWindow(element, project: project, target: target) {
                try await WindowAccess.leaveFullScreen(window)
                try Task.checkCancellation()
                _ = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                try WindowAccess.fit(window, to: frame, raise: true)
                try watch(window, pid: app.processIdentifier, frame: frame)
                NSApp.yieldActivation(to: app)
                app.activate(options: [])
                return
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        throw BarError.message("\(target.title) opened, but its project window could not be identified. Check that the folder opened successfully, then click again.")
    }

    func updateFrame(_ frame: CGRect) {
        managedWindows.removeAll { !$0.isActive }
        for window in managedWindows { window.updateFrame(frame) }
    }

    func stop() {
        for window in managedWindows { window.stop() }
        managedWindows.removeAll()
    }

    private func watch(_ element: AXUIElement, pid: pid_t, frame: CGRect) throws {
        managedWindows.removeAll { !$0.isActive }
        if let existing = managedWindows.first(where: { CFEqual($0.element, element) }) {
            existing.updateFrame(frame)
            return
        }
        let window = try ManagedWindow(element: element, pid: pid, available: frame) { [weak self] message in
            self?.reportFailure?(message)
        }
        managedWindows.append(window)
    }

    private func findWindow(_ app: AXUIElement, project: Project, target: TargetApp) -> AXUIElement? {
        guard let windows = WindowAccess.attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
        let matches = windows.filter { window in
            let title = WindowAccess.attribute(window, kAXTitleAttribute) as? String ?? ""
            if target == .herdr { return title.contains(project.terminalTitle) }
            if let document = WindowAccess.attribute(window, kAXDocumentAttribute) as? String,
               let url = URL(string: document), url.isFileURL {
                let path = url.resolvingSymlinksInPath().standardizedFileURL.path
                return path == project.path || path.hasPrefix(project.path + "/")
            }
            return WindowTitle.matches(title, projectName: project.name)
        }
        guard matches.count == 1 else { return nil }
        return matches.first
    }
}
