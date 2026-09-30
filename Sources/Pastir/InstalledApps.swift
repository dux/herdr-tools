import AppKit

struct InstalledApp: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL

    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }

    static let all: [InstalledApp] = discover()

    private static func discover() -> [InstalledApp] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let roots = ["/Applications", "/Applications/Utilities",
                     "/System/Applications", "/System/Applications/Utilities",
                     home + "/Applications"]
        var seen = Set<String>()
        var apps: [InstalledApp] = []
        for root in roots {
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let url = URL(fileURLWithPath: root).appendingPathComponent(entry)
                guard seen.insert(url.path).inserted else { continue }
                apps.append(InstalledApp(id: url.path,
                                         name: entry.replacingOccurrences(of: ".app", with: ""),
                                         url: url))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
