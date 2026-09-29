import Foundation

public enum WindowTitle {
    public static func matches(_ title: String, projectName: String) -> Bool {
        let separators = "\\s|\\[\\]()\\-\u{2013}\u{2014}"
        let name = NSRegularExpression.escapedPattern(for: projectName)
        let pattern = "(^|[" + separators + "])" + name + "($|[" + separators + "])"
        return title.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
