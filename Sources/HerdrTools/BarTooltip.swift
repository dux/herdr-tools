import AppKit
import SwiftUI

/// Tooltip for the bar icons. Native tooltips only show while the app is active,
/// which the non-activating bar almost never is.
@MainActor final class BarTooltip {
    private let panel: NSPanel
    private let host = NSHostingView(rootView: TooltipLabel(text: ""))
    private var anchor: CGRect?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        host.sizingOptions = [.intrinsicContentSize]
        panel.contentView = host
    }

    var isVisible: Bool { panel.isVisible }

    func show(_ text: String, below anchor: CGRect, on screen: NSScreen) {
        guard !panel.isVisible || anchor != self.anchor else { return }
        self.anchor = anchor
        host.rootView = TooltipLabel(text: text)
        let size = host.fittingSize
        let bounds = screen.frame.insetBy(dx: 4, dy: 0)
        let x = min(max(anchor.midX - size.width / 2, bounds.minX), bounds.maxX - size.width)
        panel.setFrame(CGRect(x: x, y: anchor.minY - 4 - size.height, width: size.width, height: size.height),
                       display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        anchor = nil
        panel.orderOut(nil)
    }
}

private struct TooltipLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(BarView.background, in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
            .fixedSize()
    }
}
