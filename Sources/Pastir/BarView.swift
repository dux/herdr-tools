import SwiftUI
import PastirCore

struct BarView: View {
    let projects: ProjectStore
    let launcher: AppLauncher
    let projectStripWidth: CGFloat
    let addFolder: () -> Void
    let launch: (TargetApp) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 18, height: 18)
                .help("Pastir")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if projects.projects.isEmpty {
                        Text("Add a project")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    ForEach(projects.projects) { project in
                        Button { projects.select(project.id) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder").frame(width: 12)
                                Text(project.name).lineLimit(1).fixedSize()
                            }
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(projects.selectedID == project.id ? Color.mint.opacity(0.16) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 7))
                                .foregroundStyle(projects.selectedID == project.id ? Color.mint : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .help(project.path)
                        .contextMenu {
                            Button("Show in Finder") {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path)
                            }
                            Button("Remove from bar", role: .destructive) { projects.remove(project.id) }
                        }
                    }
                }
            }
            .frame(width: projectStripWidth)
            Button(action: addFolder) { Image(systemName: "plus").frame(width: 20, height: 22) }
                .buttonStyle(.plain).help("Add project folder")
                .disabled(projects.isLoading)
            Divider().frame(width: 1, height: 14)

            ForEach(TargetApp.allCases) { target in
                Button { launch(target) } label: {
                    Group {
                        if launcher.launching == target {
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
            if !launcher.hasWindowAccess {
                Button(action: launcher.enableAccess) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange).frame(width: 20, height: 22)
                }
                .buttonStyle(.plain)
                .help("Enable Window Control")
                .accessibilityLabel("Enable Window Control")
            }
            Menu {
                Button("Add project folder...", action: addFolder)
                Button("Enable Window Control", action: launcher.enableAccess)
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
