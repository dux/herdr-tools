import CoreGraphics

public struct BarLayout: Sendable {
    public static let height: CGFloat = 28
    public let bar: CGRect
    public let application: CGRect

    public init(screenFrame: CGRect, visibleFrame: CGRect, contentWidth: CGFloat, topArea: CGRect? = nil) {
        let area = topArea ?? screenFrame
        let width = max(0, min(contentWidth, area.width - 16))
        bar = CGRect(x: area.midX - width / 2, y: screenFrame.maxY - Self.height,
                     width: width, height: Self.height)
        let applicationTop = min(visibleFrame.maxY, bar.minY)
        application = CGRect(x: visibleFrame.minX, y: visibleFrame.minY,
                             width: visibleFrame.width, height: max(0, applicationTop - visibleFrame.minY))
    }

    public func accessibilityFrame(primaryScreenTop: CGFloat) -> CGRect {
        CGRect(x: application.minX, y: primaryScreenTop - application.maxY,
               width: application.width, height: application.height)
    }
}
