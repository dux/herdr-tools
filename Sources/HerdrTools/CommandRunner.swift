import Foundation
import HerdrToolsCore

actor CommandRunner {
    // A GUI app inherits the launchd PATH (/usr/bin:/bin:/usr/sbin:/sbin), which has no
    // user bin dirs like ~/.local/bin, so ask the login shell for its PATH once.
    private static let loginPath: String? = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", "print -rn -- __HT__$PATH"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return ShellPath.fromLoginShell(text)
    }()

    // Fire-and-forget: used to launch apps, which may keep running.
    func run(_ command: String, folder: String) throws {
        let process = baseProcess(command, folder: folder)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    // Captures standard output and waits for the command to finish.
    func output(_ command: String) throws -> String {
        let process = baseProcess(command)
        let pipe = Pipe()
        // stderr goes to a file: a pipe nobody drains deadlocks once it fills.
        let errorURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("herdr-tools-stderr-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: errorURL) }
        let errorFile = try FileHandle(forWritingTo: errorURL)
        process.standardOutput = pipe
        process.standardError = errorFile
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try? errorFile.close()
        guard process.terminationStatus == 0 else {
            throw BarError.message(Self.failureMessage(command, errorURL: errorURL))
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func failureMessage(_ command: String, errorURL: URL) -> String {
        let detail = ((try? String(contentsOf: errorURL, encoding: .utf8)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? "Command failed: \(command)" : "Command failed: \(command)\n\(detail)"
    }

    private func baseProcess(_ command: String, folder: String? = nil) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        var environment = ProcessInfo.processInfo.environment
        if let path = Self.loginPath { environment["PATH"] = path }
        if let folder {
            environment["FOLDER"] = folder
            process.currentDirectoryURL = URL(fileURLWithPath: folder)
        }
        process.environment = environment
        return process
    }
}
