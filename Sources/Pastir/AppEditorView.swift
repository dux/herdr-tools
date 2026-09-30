import AppKit
import SwiftUI
import UniformTypeIdentifiers
import PastirCore

struct AppEditorView: View {
    let onSave: (CustomApp) -> Void
    let cancel: () -> Void

    @State private var id: UUID
    @State private var name: String
    @State private var command: String
    @State private var iconPath: String?
    @State private var icon: NSImage?
    private let isNew: Bool

    init(existing: CustomApp?, onSave: @escaping (CustomApp) -> Void, cancel: @escaping () -> Void) {
        self.onSave = onSave
        self.cancel = cancel
        self.isNew = existing == nil
        _id = State(initialValue: existing?.id ?? UUID())
        _name = State(initialValue: existing?.name ?? "")
        _command = State(initialValue: existing?.command ?? "")
        _iconPath = State(initialValue: existing?.iconPath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "Add App" : "Edit App").font(.headline)

            HStack(alignment: .top, spacing: 14) {
                preview
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Button("Choose App...", action: chooseApp)
                        Button("Choose Icon...", action: chooseIcon)
                    }
                    TextField("Name", text: $name)
                    TextField("Command", text: $command)
                    Text("Use $FOLDER for the selected project folder.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button("Save", action: save).keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty || trimmedCommand.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private var preview: some View {
        Group {
            if let image = icon ?? iconPath.flatMap({ NSImage(contentsOfFile: $0) }) {
                Image(nsImage: image).resizable().interpolation(.high).frame(width: 48, height: 48)
            } else {
                Image(systemName: "app").font(.system(size: 26)).foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
            }
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedCommand: String { command.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose App"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        name = url.deletingPathExtension().lastPathComponent
        icon = NSWorkspace.shared.icon(forFile: url.path)
        command = "open -a " + LaunchText.shellQuote(url.path) + " \"$FOLDER\""
    }

    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.title = "Choose Icon"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        icon = image
    }

    private func save() {
        var app = CustomApp(id: id, name: trimmedName, command: trimmedCommand, iconPath: iconPath)
        if let icon, let path = AppIconStore.write(icon, id: id) {
            app.iconPath = path
        }
        onSave(app)
    }
}

enum AppIconStore {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ProjectBar/icons")
    }

    static func write(_ image: NSImage, id: UUID) -> String? {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        let url = directory.appendingPathComponent("\(id.uuidString.lowercased()).png")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }
}
