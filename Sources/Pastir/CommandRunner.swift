import Foundation

actor CommandRunner {
    // Fire-and-forget: used to launch apps, which may keep running.
    func run(_ command: String, folder: String) throws {
        let process = baseProcess(command)
        var environment = ProcessInfo.processInfo.environment
        environment["FOLDER"] = folder
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: folder)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    // Captures standard output and waits for the command to finish.
    func output(_ command: String) throws -> String {
        let process = baseProcess(command)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BarError.message("Command failed: \(command)")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func baseProcess(_ command: String) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        return process
    }
}
