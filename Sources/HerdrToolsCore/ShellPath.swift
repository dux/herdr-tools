import Foundation

public enum ShellPath {
    // Reads the PATH out of the login shell's `print -rn -- <marker>$PATH` output,
    // keeping it regardless of anything the user's rc prints ahead of the marker.
    public static func fromLoginShell(_ output: String) -> String? {
        guard let marker = output.range(of: "__HT__") else { return nil }
        let path = output[marker.upperBound...]
        return path.isEmpty ? nil : String(path)
    }
}
