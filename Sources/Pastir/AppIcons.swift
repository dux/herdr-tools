import AppKit
import PastirCore

enum AppIcons {
    // The icon comes from the .app referenced by the command; callers fall
    // back to the app's SF Symbol, then a generic icon.
    static func icon(for app: CustomApp) -> NSImage? {
        guard let url = appBundleURL(in: app.command) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func icon(inCommand command: String) -> NSImage? {
        guard let url = appBundleURL(in: command) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func appBundleURL(in command: String) -> URL? {
        let words = tokenize(command)
        if let flag = words.firstIndex(of: "-a"), flag + 1 < words.count {
            let argument = words[flag + 1]
            if argument.contains("/") || argument.hasSuffix(".app") { return existingApp(argument) }
            if let match = InstalledApp.all.first(where: { $0.name.caseInsensitiveCompare(argument) == .orderedSame }) {
                return match.url
            }
        }
        if let flag = words.firstIndex(of: "-b"), flag + 1 < words.count,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: words[flag + 1]) {
            return url
        }
        for word in words where word.hasSuffix(".app") {
            if let url = existingApp(word) { return url }
        }
        return nil
    }

    private static func existingApp(_ path: String) -> URL? {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // Splits a shell command into words, keeping quoted paths intact.
    private static func tokenize(_ command: String) -> [String] {
        let pattern = #""([^"]*)"|'([^']*)'|(\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let text = command as NSString
        var words: [String] = []
        regex.enumerateMatches(in: command, range: NSRange(location: 0, length: text.length)) { match, _, _ in
            guard let match else { return }
            for group in 1...3 where match.range(at: group).location != NSNotFound {
                words.append(text.substring(with: match.range(at: group)))
                return
            }
        }
        return words
    }
}
