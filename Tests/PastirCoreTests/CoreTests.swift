import Foundation
import CoreGraphics
import Testing
@testable import PastirCore

@Test func compactBarOverlaysMenuAndRespectsDock() {
    let layout = BarLayout(screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                           visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 805), contentWidth: 300)
    #expect(layout.bar == CGRect(x: 570, y: 872, width: 300, height: 28))
    #expect(layout.application == CGRect(x: 0, y: 70, width: 1440, height: 802))
    #expect(layout.accessibilityFrame(primaryScreenTop: 900) == CGRect(x: 0, y: 28, width: 1440, height: 802))
}

@Test func secondaryScreenCoordinateConversion() {
    let screen = CGRect(x: -1920, y: 900, width: 1920, height: 1080)
    let layout = BarLayout(screenFrame: screen, visibleFrame: screen, contentWidth: 300)
    #expect(layout.accessibilityFrame(primaryScreenTop: 900) == CGRect(x: -1920, y: -1052, width: 1920, height: 1052))
}

@Test func notchAreaKeepsCompactBarVisible() {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let left = CGRect(x: 0, y: 868, width: 650, height: 32)
    let layout = BarLayout(screenFrame: screen, visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 868),
                           contentWidth: 800, topArea: left)
    #expect(layout.bar.width == 634)
    #expect(left.contains(layout.bar))
    #expect(layout.application.maxY == 868)
}

@Test func normalMenuBarDoesNotAddAnotherStripeMargin() {
    let visible = CGRect(x: 0, y: 70, width: 1440, height: 798)
    let layout = BarLayout(screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                           visibleFrame: visible, contentWidth: 300)
    #expect(layout.application == visible)
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

@Test func windowNamesMustMatchCompleteProjectNames() {
    #expect(WindowTitle.matches("main.swift - app - Visual Studio Code", projectName: "app"))
    #expect(!WindowTitle.matches("main.swift - myapp - Visual Studio Code", projectName: "app"))
    #expect(WindowTitle.matches("my-app [main]", projectName: "my-app"))
    #expect(WindowTitle.matches("file - Project (2) - VS Code", projectName: "Project (2)"))
    #expect(!WindowTitle.matches("file - Project 222 - VS Code", projectName: "Project (2)"))
}
