import Foundation

actor ScriptRunner {
    func run(_ source: String) throws {
        guard let script = NSAppleScript(source: source) else {
            throw BarError.message("Could not prepare the Terminal command.")
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            throw BarError.message((error[NSAppleScript.errorMessage] as? String)
                ?? "Terminal automation failed. Allow Pastir to control Terminal in System Settings > Privacy & Security > Automation.")
        }
    }
}
