import SwiftUI
import PastirCore

struct BarView: View {
    let projects: ProjectStore
    let launcher: AppLauncher
    let apps: AppStore
    let projectStripWidth: CGFloat
    let addFolder: () -> Void
    let addApp: () -> Void
    let editApp: (CustomApp) -> Void
    let removeApp: (CustomApp) -> Void
    let launch: (TargetApp) -> Void
    let launchCustom: (CustomApp) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 18, height: 18)
                .help("Pastir")

            Menu {
                ForEach(projects.projects) { project in
                    Button {
                        projects.select(project.id)
                    } label: {
                        if projects.selectedID == project.id {
                            Label(project.name, systemImage: "checkmark")
                        } else {
                            Text(project.name)
                        }
                    }
                }
                if projects.projects.isEmpty {
                    Text("No folders")
                }
                Divider()
                Button("Add folder to bottom", action: addFolder)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                    Text(projects.selected?.name ?? "Add a project")
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.mint.opacity(0.16), in: RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(.mint)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .frame(width: projectStripWidth, alignment: .leading)
            .help(projects.selected?.path ?? "Choose a project folder")
            Divider().frame(width: 1, height: 14)

            ForEach(TargetApp.allCases) { target in
                Button { launch(target) } label: {
                    Group {
                        if launcher.launching == .builtin(target) {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: target.symbol)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 22)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help(target.title)
                .accessibilityLabel(target.title)
                .disabled(projects.selected == nil || launcher.launching != nil)
            }
            ForEach(apps.apps) { app in
                Button { launchCustom(app) } label: {
                    Group {
                        if launcher.launching == .custom(app.id) {
                            ProgressView().controlSize(.mini)
                        } else if let path = app.iconPath, let image = NSImage(contentsOfFile: path) {
                            Image(nsImage: image).resizable().interpolation(.high).frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "app")
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 22)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help(app.name)
                .accessibilityLabel(app.name)
                .disabled(projects.selected == nil || launcher.launching != nil)
                .contextMenu {
                    Button("Edit...") { editApp(app) }
                    Button("Remove from bar", role: .destructive) { removeApp(app) }
                }
            }
            Button(action: addApp) { Image(systemName: "plus").frame(width: 20, height: 22) }
                .buttonStyle(.plain).help("Add app")
            Menu {
                Button("Add project folder...", action: addFolder)
                Divider()
                Button("Quit Pastir") { NSApp.terminate(nil) }
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
