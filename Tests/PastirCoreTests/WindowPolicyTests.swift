import CoreGraphics
import Testing
@testable import PastirCore

private let workspace = CGRect(x: 0, y: 25, width: 1440, height: 805)
private let available = CGRect(x: 0, y: 73, width: 1440, height: 757)

@Test func maximizedWindowLeavesRoomForStripe() {
    #expect(WindowPolicy.correction(for: workspace, workspace: workspace, available: available) == available)
}

@Test func correctionSettlesAfterOneResize() {
    let corrected = WindowPolicy.correction(for: workspace, workspace: workspace, available: available)
    #expect(corrected == available)
    #expect(WindowPolicy.correction(for: available, workspace: workspace, available: available) == nil)
}

@Test func terminalGridRoundingDoesNotCauseResizeLoop() {
    let terminal = CGRect(x: 0, y: 73, width: 1433, height: 746)
    #expect(WindowPolicy.correction(for: terminal, workspace: workspace, available: available) == nil)
}

@Test func smallWindowCanOverlapStripeWithoutBeingMaximized() {
    let small = CGRect(x: 300, y: 25, width: 700, height: 500)
    #expect(WindowPolicy.correction(for: small, workspace: workspace, available: available) == nil)
}

@Test func windowOnAnotherDisplayIsLeftAlone() {
    let other = CGRect(x: 1440, y: 25, width: 1440, height: 805)
    #expect(WindowPolicy.correction(for: other, workspace: workspace, available: available) == nil)
}

@Test func maximizedWindowOnDisplayAbovePrimaryUsesNegativeCoordinates() {
    let screen = CGRect(x: -1920, y: -1080, width: 1920, height: 1080)
    let target = CGRect(x: -1920, y: -1032, width: 1920, height: 1032)
    #expect(WindowPolicy.correction(for: screen, workspace: screen, available: target) == target)
}
