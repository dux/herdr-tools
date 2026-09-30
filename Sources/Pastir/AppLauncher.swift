import AppKit
import Observation
import PastirCore

@MainActor @Observable final class AppLauncher {
    private(set) var launching: UUID?
    var message: String?
    private let commands = CommandRunner()

    func open(_ custom: CustomApp, project: Project) async {
        guard launching == nil else { return }
        launching = custom.id
        defer { launching = nil }
        do {
            guard FileManager.default.fileExists(atPath: project.path) else {
                throw BarError.message("Project folder no longer exists: \(project.path)")
            }
            try await commands.run(custom.command, folder: project.path)
        } catch {
            message = error.localizedDescription
        }
    }
}
