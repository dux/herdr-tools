import AppKit
import Observation
import PastirCore

enum LaunchID: Equatable {
    case builtin(TargetApp)
    case custom(UUID)
}

@MainActor @Observable final class AppLauncher {
    private(set) var launching: LaunchID?
    var message: String?
    private let scripts = ScriptRunner()
    private let commands = CommandRunner()

    func openCustom(_ custom: CustomApp, project: Project) async {
        guard launching == nil else { return }
        launching = .custom(custom.id)
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

    func open(_ target: TargetApp, project: Project) async {
        guard launching == nil else { return }
        launching = .builtin(target)
        defer { launching = nil }
        do {
            guard FileManager.default.fileExists(atPath: project.path) else {
                throw BarError.message("Project folder no longer exists: \(project.path)")
            }
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleID) else {
                throw BarError.message("\(target.title) is not installed.")
            }
            if target == .herdr {
                let executable = try herdrExecutable()
                try await scripts.run(LaunchText.herdrScript(project: project, executable: executable))
                guard NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).first != nil else {
                    throw BarError.message("Terminal did not start.")
                }
            } else {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                _ = try await NSWorkspace.shared.open(
                    [URL(fileURLWithPath: project.path)],
                    withApplicationAt: appURL, configuration: configuration)
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func herdrExecutable() throws -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [home + "/.local/bin/herdr", "/opt/homebrew/bin/herdr", "/usr/local/bin/herdr"]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw BarError.message("Herdr was not found in ~/.local/bin, /opt/homebrew/bin, or /usr/local/bin.")
        }
        return executable
    }
}
