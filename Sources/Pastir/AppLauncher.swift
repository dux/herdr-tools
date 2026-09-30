import AppKit
import Foundation
import Observation
import PastirCore

@MainActor @Observable final class AppLauncher {
    private(set) var launching: UUID?
    private(set) var copiedFolder = false
    var message: String?
    private let herdr = HerdrClient()
    private let commands = CommandRunner()

    func open(_ custom: CustomApp) async {
        guard launching == nil else { return }
        launching = custom.id
        defer { launching = nil }
        do {
            let folder = try await herdr.focusedFolder()
            try await commands.run(custom.command, folder: folder)
        } catch {
            message = error.localizedDescription
        }
    }

    func copyFocusedFolder() async {
        do {
            let folder = try await herdr.focusedFolder()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(LaunchText.abbreviateHome(folder), forType: .string)
            copiedFolder = true
            try? await Task.sleep(for: .seconds(1.2))
            copiedFolder = false
        } catch {
            message = error.localizedDescription
        }
    }
}
