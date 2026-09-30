import AppKit
import SwiftUI
import HerdrToolsCore

struct AppEditorView: View {
    let onSave: (CustomApp) -> Void
    let cancel: () -> Void

    @State private var id: UUID
    @State private var name: String
    @State private var command: String
    @State private var symbol: String
    @State private var showingSymbols = false
    private let isNew: Bool

    init(existing: CustomApp?, onSave: @escaping (CustomApp) -> Void, cancel: @escaping () -> Void) {
        self.onSave = onSave
        self.cancel = cancel
        self.isNew = existing == nil
        _id = State(initialValue: existing?.id ?? UUID())
        _name = State(initialValue: existing?.name ?? "")
        _command = State(initialValue: existing?.command ?? "")
        _symbol = State(initialValue: existing?.symbol ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "Add App" : "Edit App").font(.headline)

            HStack(alignment: .top, spacing: 14) {
                preview
                VStack(alignment: .leading, spacing: 10) {
                    appPicker
                    TextField("Name", text: $name)
                    TextField("Command", text: $command)
                    HStack(spacing: 8) {
                        TextField("Icon: SF Symbol name (optional)", text: $symbol)
                        Button("Choose Icon...") { showingSymbols = true }
                            .popover(isPresented: $showingSymbols, arrowEdge: .bottom) {
                                SymbolPicker(symbol: $symbol) { showingSymbols = false }
                            }
                    }
                    Text("The icon comes from the app in the command; $FOLDER is the folder focused in Herdr.")
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
        .frame(width: 540)
    }

    private var appPicker: some View {
        Menu {
            if InstalledApp.all.isEmpty {
                Text("No applications found")
            }
            ForEach(InstalledApp.all) { app in
                Button { apply(app) } label: {
                    Label {
                        Text(app.name)
                    } icon: {
                        Image(nsImage: app.icon)
                    }
                }
            }
        } label: {
            Label("Choose App...", systemImage: "square.grid.2x2")
        }
        .fixedSize()
        .disabled(InstalledApp.all.isEmpty)
    }

    private var preview: some View {
        Group {
            if let image = AppIcons.icon(inCommand: command) {
                Image(nsImage: image).resizable().interpolation(.high).frame(width: 48, height: 48)
            } else if let image = NSImage(systemSymbolName: trimmedSymbol, accessibilityDescription: nil) {
                Image(nsImage: image).resizable().interpolation(.high).frame(width: 36, height: 36)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "app").font(.system(size: 26)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 48, height: 48)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedCommand: String { command.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedSymbol: String { symbol.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func apply(_ app: InstalledApp) {
        name = app.name
        command = "open -a " + LaunchText.shellQuote(app.url.path) + " \"$FOLDER\""
        symbol = ""
    }

    private func save() {
        onSave(CustomApp(id: id, name: trimmedName, command: trimmedCommand,
                         symbol: trimmedSymbol.isEmpty ? nil : trimmedSymbol))
    }
}
