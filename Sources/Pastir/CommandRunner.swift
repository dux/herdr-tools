import Foundation

actor CommandRunner {
    func run(_ command: String, folder: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        var environment = ProcessInfo.processInfo.environment
        environment["FOLDER"] = folder
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: folder)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }
}
