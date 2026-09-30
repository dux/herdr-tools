import Foundation
import CoreGraphics
import Testing
@testable import PastirCore

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

@Test func shellArgumentsPreserveMetacharacters() {
    #expect(LaunchText.shellQuote("/a/b's $(touch nope)`hello`") == "'/a/b'\\''s $(touch nope)`hello`'")
    #expect(LaunchText.appleScriptQuote("a\"b\\c\nd") == "\"a\\\"b\\\\c\\nd\"")
}

@Test func duplicateFolderNamesHaveDifferentSessions() {
    let a = Project(url: URL(fileURLWithPath: "/one/repo"))
    let b = Project(url: URL(fileURLWithPath: "/two/repo"))
    #expect(a.name == b.name)
    #expect(a.sessionName != b.sessionName)
    #expect(a.terminalTitle != b.terminalTitle)
}

@Test func projectIdentitySurvivesPersistence() throws {
    let project = Project(url: URL(fileURLWithPath: "/projects/my app"))
    let restored = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
    #expect(project == restored)
    #expect(project.sessionName == restored.sessionName)
}

@Test func customAppSurvivesPersistence() throws {
    let app = CustomApp(name: "Fork", command: "open -a '/Applications/Fork.app' \"$FOLDER\"",
                        iconPath: "/tmp/fork.png")
    let restored = try JSONDecoder().decode(CustomApp.self, from: JSONEncoder().encode(app))
    #expect(app == restored)
}
