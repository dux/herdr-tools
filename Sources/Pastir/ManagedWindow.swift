import AppKit
import ApplicationServices
import PastirCore

@MainActor final class ManagedWindow: NSObject {
    let element: AXUIElement
    private var available: CGRect
    private var observer: AXObserver?
    private var task: Task<Void, Never>?
    private var needsCheck = false
    private var isStopped = false
    private var lastFailure: String?
    private let reportFailure: (String) -> Void

    init(element: AXUIElement, pid: pid_t, available: CGRect, reportFailure: @escaping (String) -> Void) throws {
        self.element = element
        self.available = available
        self.reportFailure = reportFailure
        super.init()
        AXUIElementSetMessagingTimeout(element, 0.25)
        let callback: AXObserverCallback = { _, _, notification, context in
            guard let context else { return }
            // The observer source is attached exclusively to the main run loop.
            MainActor.assumeIsolated {
                let owner = Unmanaged<ManagedWindow>.fromOpaque(context).takeUnretainedValue()
                if notification as String == kAXUIElementDestroyedNotification {
                    owner.stop()
                } else {
                    owner.scheduleCheck()
                }
            }
        }
        var created: AXObserver?
        guard AXObserverCreate(pid, callback, &created) == .success, let created else {
            throw BarError.message("App opened, but Pastir could not watch its window for maximize changes.")
        }
        observer = created
        let context = Unmanaged.passUnretained(self).toOpaque()
        let resized = AXObserverAddNotification(created, element, kAXResizedNotification as CFString, context)
        guard resized == .success else {
            observer = nil
            throw BarError.message("This app does not expose window resize notifications to Pastir.")
        }
        for name in [kAXMovedNotification, kAXWindowDeminiaturizedNotification, kAXUIElementDestroyedNotification] {
            _ = AXObserverAddNotification(created, element, name as CFString, context)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    var isActive: Bool { !isStopped }

    func updateFrame(_ frame: CGRect) {
        available = frame
        scheduleCheck()
    }

    func stop() {
        isStopped = true
        task?.cancel()
        task = nil
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func spaceChanged() { scheduleCheck() }

    private func scheduleCheck() {
        guard !isStopped else { return }
        if task != nil {
            needsCheck = true
            return
        }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(150))
                try await self.correctWindow()
            } catch is CancellationError {
                return
            } catch {
                let message = error.localizedDescription
                if self.lastFailure != message {
                    self.lastFailure = message
                    self.reportFailure(message)
                }
                self.stop()
            }
            self.task = nil
            if self.needsCheck {
                self.needsCheck = false
                self.scheduleCheck()
            }
        }
    }

    private func correctWindow() async throws {
        guard !isStopped, AXIsProcessTrusted(),
              WindowAccess.attribute(element, kAXMinimizedAttribute) as? Bool != true else { return }
        if WindowAccess.attribute(element, "AXFullScreen") as? Bool == true {
            try await WindowAccess.leaveFullScreen(element)
            try Task.checkCancellation()
            try await maximize()
            return
        }
        guard let current = WindowAccess.frame(element) else { return }
        let workspace = CGRect(x: available.minX, y: available.minY - BarLayout.height,
                               width: available.width, height: available.height + BarLayout.height)
        if let correction = WindowPolicy.correction(for: current, workspace: workspace, available: available) {
            try await maximize(to: correction)
        }
    }

    private func maximize(to frame: CGRect? = nil) async throws {
        let target = frame ?? available
        let workspace = CGRect(x: target.minX, y: target.minY - BarLayout.height,
                               width: target.width, height: target.height + BarLayout.height)
        for _ in 0..<4 {
            try Task.checkCancellation()
            try WindowAccess.fit(element, to: target)
            try await Task.sleep(for: .milliseconds(250))
            guard let actual = WindowAccess.frame(element) else { return }
            if WindowPolicy.correction(for: actual, workspace: workspace, available: target) == nil { return }
        }
        throw BarError.message("This app could not keep its window below Pastir. Its minimum size or another window manager may be preventing it. Click its app button to retry.")
    }
}
