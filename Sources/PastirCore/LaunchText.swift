import Foundation

public enum LaunchText {
    public static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func appleScriptQuote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r") + "\""
    }

    public static func herdrScript(project: Project, executable: String) -> String {
        let title = appleScriptQuote(project.terminalTitle)
        let command = "cd " + shellQuote(project.path) + " && " + shellQuote(executable)
            + " --session " + shellQuote(project.sessionName)
        return """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if custom title of t ends with \(appleScriptQuote(project.terminalMarker)) then
                        set custom title of t to \(title)
                        set selected of t to true
                        set index of w to 1
                        activate
                        return
                    end if
                end repeat
            end repeat
            set t to do script \(appleScriptQuote(command))
            set custom title of t to \(title)
            set title displays custom title of t to true
            activate
        end tell
        """
    }
}
