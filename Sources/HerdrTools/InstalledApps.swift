import AppKit
import SwiftUI

struct InstalledApp: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL

    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
    var bundleID: String? { Bundle(url: url)?.bundleIdentifier }

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

struct InstalledAppPicker: View {
    let onSelect: (InstalledApp) -> Void
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search apps", text: $query)
                .focused($searchFocused)
                .onSubmit { if let app = matches.first { onSelect(app) } }
            if matches.isEmpty {
                Text("No applications found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(matches) { app in
                            InstalledAppRow(app: app) { onSelect(app) }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 320, height: 360)
        .onAppear { searchFocused = true }
    }

    private var matches: [InstalledApp] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return InstalledApp.all }
        return InstalledApp.all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}

private struct InstalledAppRow: View {
    let app: InstalledApp
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: 18, height: 18)
                Text(app.name).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: 26)
            .contentShape(Rectangle())
            .background(hovering ? Color.accentColor.opacity(0.25) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
