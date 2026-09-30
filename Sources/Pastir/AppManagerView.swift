import SwiftUI
import PastirCore

struct AppManagerView: View {
    let apps: AppStore
    let add: () -> Void
    let edit: (CustomApp) -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Applications").font(.headline)

            if apps.apps.isEmpty {
                Text("No applications yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(apps.apps) { app in
                        HStack(spacing: 10) {
                            icon(for: app)
                            Text(app.name).lineLimit(1)
                            Spacer()
                            Button("Edit") { edit(app) }
                            Button { apps.remove(app.id) } label: { Image(systemName: "trash") }
                                .help("Remove")
                        }
                    }
                    .onMove { apps.move(from: $0, to: $1) }
                }
                .listStyle(.inset)
            }

            HStack {
                Text("Drag a row to reorder.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Add application...", action: add)
                Button("Done", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460, height: 340)
    }

    @ViewBuilder private func icon(for app: CustomApp) -> some View {
        if let image = AppIcons.icon(for: app) {
            Image(nsImage: image).resizable().interpolation(.high).frame(width: 20, height: 20)
        } else {
            Image(systemName: app.symbol.flatMap { $0.isEmpty ? nil : $0 } ?? "app")
                .frame(width: 20, height: 20)
        }
    }
}
