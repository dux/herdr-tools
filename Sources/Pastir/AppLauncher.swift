import AppKit
import Observation
import PastirCore

@MainActor @Observable final class AppLauncher {
    private(set) var launching: TargetApp?
    private(set) var hasWindowAccess = false
    var message: String?
    private let placer: WindowPlacer
    private let scripts = ScriptRunner()

    init(placer: WindowPlacer) {
        self.placer = placer
        placer.reportFailure = { [weak self] message in self?.message = message }
        refreshAccess()
    }

    func refreshAccess() { hasWindowAccess = placer.isTrusted }
    func enableAccess() { placer.requestAccess() }
    func updateFrame(_ frame: CGRect) { placer.updateFrame(frame) }
    func stopWindowManagement() { placer.stop() }

    func open(_ target: TargetApp, project: Project, frame: CGRect) async {
        guard launching == nil else { return }
        launching = target
        defer { launching = nil; refreshAccess() }
        do {
            guard FileManager.default.fileExists(atPath: project.path) else {
                throw BarError.message("Project folder no longer exists: \(project.path)")
            }
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleID) else {
                throw BarError.message("\(target.title) is not installed.")
            }
            let app: NSRunningApplication
            if target == .herdr {
                let executable = try herdrExecutable()
                try await scripts.run(LaunchText.herdrScript(project: project, executable: executable))
                guard let terminal = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).first else {
                    throw BarError.message("Terminal did not start.")
                }
                app = terminal
            } else {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                app = try await NSWorkspace.shared.open(
                    [URL(fileURLWithPath: project.path)],
                    withApplicationAt: appURL, configuration: configuration)
            }
            try await placer.place(app: app, project: project, target: target, frame: frame)
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
