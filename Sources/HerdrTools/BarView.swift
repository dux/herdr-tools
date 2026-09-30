import SwiftUI
import HerdrToolsCore

struct BarView: View {
    let launcher: AppLauncher
    let apps: AppStore
    let copyFolder: () -> Void
    let addApp: () -> Void
    let manageApps: () -> Void
    let switchDisplay: () -> Void
    let editApp: (CustomApp) -> Void
    let removeApp: (CustomApp) -> Void
    let launchCustom: (CustomApp) -> Void

    private var navIcon: NSImage {
        if let url = Bundle.main.url(forResource: "HerdrIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) { return image }
        return NSApp.applicationIconImage
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: navIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .help("Herdr - drag to move")

            Button(action: copyFolder) {
                Image(systemName: launcher.copiedFolder ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(launcher.copiedFolder ? Color.mint : Color.primary)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 22)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("Copy focused folder path")

            ForEach(apps.apps) { app in
                Button { launchCustom(app) } label: {
                    Group {
                        if launcher.launching == app.id {
                            ProgressView().controlSize(.mini)
                        } else if let image = AppIcons.icon(for: app) {
                            Image(nsImage: image).resizable().interpolation(.high).frame(width: 16, height: 16)
                        } else {
                            Image(systemName: app.symbol.flatMap { $0.isEmpty ? nil : $0 } ?? "app")
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 22)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help(app.name)
                .accessibilityLabel(app.name)
                .disabled(launcher.launching != nil)
                .contextMenu {
                    Button("Edit...") { editApp(app) }
                    Button("Remove from bar", role: .destructive) { removeApp(app) }
                }
            }

            Menu {
                Button("Add application", action: addApp)
                Button("Edit applications", action: manageApps)
                Button("Switch display", action: switchDisplay)
                Divider()
                Button("Quit Herdr Tools") { NSApp.terminate(nil) }
            } label: { Image(systemName: "ellipsis").frame(width: 22, height: 22) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
        .padding(.horizontal, 8)
        .frame(height: BarLayout.height)
        .background(Color(red: 0.075, green: 0.085, blue: 0.105),
                    in: UnevenRoundedRectangle(bottomLeadingRadius: 7, bottomTrailingRadius: 7))
        .overlay {
            UnevenRoundedRectangle(bottomLeadingRadius: 7, bottomTrailingRadius: 7)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }
}
