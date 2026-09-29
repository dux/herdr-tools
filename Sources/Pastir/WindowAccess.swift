import AppKit
import ApplicationServices

@MainActor enum WindowAccess {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func frame(_ window: AXUIElement) -> CGRect? {
        guard let position = attribute(window, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(window, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        // CF type IDs establish the concrete types before these casts.
        let pointValue = unsafeDowncast(position, to: AXValue.self)
        let sizeValue = unsafeDowncast(size, to: AXValue.self)
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(pointValue, .cgPoint, &point), AXValueGetValue(sizeValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    static func leaveFullScreen(_ window: AXUIElement) async throws {
        guard attribute(window, "AXFullScreen") as? Bool == true else { return }
        let result = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse)
        guard result == .success else {
            throw BarError.message("This app does not allow Pastir to exit full-screen mode. Exit full screen manually, then click its button in Pastir.")
        }
        for _ in 0..<40 {
            try await Task.sleep(for: .milliseconds(100))
            if attribute(window, "AXFullScreen") as? Bool == false {
                // The attribute changes before the Space transition animation finishes.
                try await Task.sleep(for: .milliseconds(500))
                return
            }
        }
        throw BarError.message("The app did not finish leaving full-screen mode.")
    }

    static func fit(_ window: AXUIElement, to frame: CGRect, raise: Bool = false) throws {
        var point = frame.origin
        var size = frame.size
        guard let position = AXValueCreate(.cgPoint, &point), let dimensions = AXValueCreate(.cgSize, &size) else {
            throw BarError.message("Could not calculate the window position.")
        }
        // Moving before and after sizing avoids screen-edge constraints during transfer.
        _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        let sized = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
        let moved = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        guard sized == .success, moved == .success else {
            throw BarError.message("The app did not allow its window to be resized or moved.")
        }
        if raise {
            _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
    }
}
