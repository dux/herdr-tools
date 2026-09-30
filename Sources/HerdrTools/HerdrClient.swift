import HerdrToolsCore

actor HerdrClient {
    private let commands = CommandRunner()

    func focusedFolder() async throws -> String {
        let json = try await commands.output("herdr pane list")
        guard let folder = HerdrPanes.focusedFolder(json: json), !folder.isEmpty else {
            throw BarError.message("Herdr has no focused folder. Open a Herdr pane and try again.")
        }
        return folder
    }
}
