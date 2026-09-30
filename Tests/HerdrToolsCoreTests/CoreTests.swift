import Foundation
import CoreGraphics
import Testing
@testable import HerdrToolsCore

@Test func compactBarSitsAtTop() {
    let layout = BarLayout(screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), contentWidth: 300)
    #expect(layout.bar == CGRect(x: 936, y: 872, width: 300, height: 28))
}

@Test func notchAreaKeepsCompactBarVisible() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let left = CGRect(x: 0, y: 868, width: 650, height: 32)
    let layout = BarLayout(screenFrame: screen, contentWidth: 800, topArea: left)
    #expect(layout.bar.width == 634)
    #expect(left.contains(layout.bar))
}

@Test func barLeadingEdgeAnchorsAtSixtyFivePercent() {
    let layout = BarLayout(screenFrame: CGRect(x: 0, y: 0, width: 1600, height: 900), contentWidth: 400)
    #expect(layout.bar.minX == 1040)
}

@Test func wideBarIsClampedInsideTheTopArea() {
    let layout = BarLayout(screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), contentWidth: 800)
    #expect(layout.bar.minX == 640)
}

@Test func explicitOriginOverridesDefaultAnchor() {
    let layout = BarLayout(screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), contentWidth: 300, originX: 100)
    #expect(layout.bar.minX == 100)
}

@Test func explicitOriginIsClampedToTopArea() {
    let layout = BarLayout(screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), contentWidth: 300, originX: 2000)
    #expect(layout.bar.minX == 1140)
}

@Test func shellArgumentsPreserveMetacharacters() {
    #expect(LaunchText.shellQuote("/a/b's $(touch nope)`hello`") == "'/a/b'\\''s $(touch nope)`hello`'")
}

@Test func homePathsAreAbbreviated() {
    #expect(LaunchText.abbreviateHome("/Users/me/dev/app", home: "/Users/me") == "~/dev/app")
    #expect(LaunchText.abbreviateHome("/Users/me", home: "/Users/me") == "~")
    #expect(LaunchText.abbreviateHome("/other/app", home: "/Users/me") == "/other/app")
    #expect(LaunchText.abbreviateHome("/Users/melon", home: "/Users/me") == "/Users/melon")
}

@Test func focusedPaneFolderPrefersForegroundCwd() {
    let json = """
    {"result":{"panes":[
      {"focused":false,"foreground_cwd":"/one","cwd":"/one"},
      {"focused":true,"foreground_cwd":"/two","cwd":"/also-two"}
    ]}}
    """
    #expect(HerdrPanes.focusedFolder(json: json) == "/two")
}

@Test func focusedPaneFolderFallsBackToCwd() {
    let json = #"{"result":{"panes":[{"focused":true,"cwd":"/only"}]}}"#
    #expect(HerdrPanes.focusedFolder(json: json) == "/only")
}

@Test func missingFocusedPaneReturnsNil() {
    let json = #"{"result":{"panes":[{"focused":false,"cwd":"/one"}]}}"#
    #expect(HerdrPanes.focusedFolder(json: json) == nil)
    #expect(HerdrPanes.focusedFolder(json: "not json") == nil)
}

@Test func customAppSurvivesPersistence() throws {
    let app = CustomApp(name: "Fork", command: "open -a '/Applications/Fork.app' \"$FOLDER\"",
                        symbol: "arrow.triangle.branch")
    let restored = try JSONDecoder().decode(CustomApp.self, from: JSONEncoder().encode(app))
    #expect(app == restored)
}
