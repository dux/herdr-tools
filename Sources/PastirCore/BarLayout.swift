import CoreGraphics

public struct BarLayout: Sendable {
    public static let height: CGFloat = 28
    public let bar: CGRect

    public init(screenFrame: CGRect, contentWidth: CGFloat, topArea: CGRect? = nil) {
        let area = topArea ?? screenFrame
        let width = max(0, min(contentWidth, area.width - 16))
        let anchor = screenFrame.minX + screenFrame.width * 0.65
        let x = min(max(anchor, area.minX), max(area.minX, area.maxX - width))
        bar = CGRect(x: x, y: screenFrame.maxY - Self.height,
                     width: width, height: Self.height)
    }
}
