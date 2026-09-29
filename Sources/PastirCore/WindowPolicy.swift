import CoreGraphics

public enum WindowPolicy {
    public static func correction(for frame: CGRect, workspace: CGRect, available: CGRect) -> CGRect? {
        guard workspace.contains(CGPoint(x: frame.midX, y: frame.midY)),
              frame.width >= workspace.width * 0.95,
              frame.height >= available.height * 0.95 else { return nil }
        // Terminal windows round sizes to their character grid.
        let alreadyFits = abs(frame.minX - available.minX) <= 2
            && abs(frame.minY - available.minY) <= 2
            && frame.width <= available.width + 2
            && frame.height <= available.height + 2
            && available.width - frame.width <= 32
            && available.height - frame.height <= 32
        return alreadyFits ? nil : available
    }
}
