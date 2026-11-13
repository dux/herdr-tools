import SwiftUI
import HerdrToolsCore

struct BarView: View {
    static let background = Color(red: 0.075, green: 0.085, blue: 0.105)
    static let spacing: CGFloat = 6
    static let coordinateSpace = "bar"

    let launcher: AppLauncher
    let apps: AppStore
    let focus: FocusWatcher
    let sleep: SleepBlocker
    let copyFolder: () -> Void
    let addApp: () -> Void
    let manageApps: () -> Void
    let switchDisplay: () -> Void
    let chooseFocusApp: () -> Void
    let editApp: (CustomApp) -> Void
    let removeApp: (CustomApp) -> Void
    let launchCustom: (CustomApp) -> Void
    let reportHits: @MainActor @Sendable ([BarHit]) -> Void
    let reportWidth: (CGFloat) -> Void

    private var navIcon: NSImage {
        if let url = Bundle.main.url(forResource: "HerdrIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) { return image }
        return NSApp.applicationIconImage
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            Image(nsImage: navIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .barHit("Drag to move")

            Button(action: copyFolder) {
                Image(systemName: launcher.copiedFolder ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(launcher.copiedFolder ? Color.mint : Color.primary)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 24, height: 22)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .barHit("Copy focused folder path")

            sleepMenu

            if !apps.apps.isEmpty {
                Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 14)
            }

            ForEach(apps.apps) { app in
                Button { launchCustom(app) } label: {
                    Group {
                        if launcher.launching == app.id {
                            ProgressView().controlSize(.mini)
                        } else if let image = AppIcons.icon(for: app) {
                            Image(nsImage: image).resizable().interpolation(.high).frame(width: 18, height: 18)
                        } else {
                            Image(systemName: app.symbol.flatMap { $0.isEmpty ? nil : $0 } ?? "app")
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 24, height: 22)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(app.name)
                .barHit(app.name, hasContextMenu: true)
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
                Button("Show only when \(focus.appName ?? "app") is in focus...", action: chooseFocusApp)
                Divider()
                Button("Quit Herdr Tools") { NSApp.terminate(nil) }
            } label: { Image(systemName: "ellipsis").frame(width: 22, height: 22) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
        .padding(.horizontal, 8)
        // The panel is sized from this natural width, so measure before the panel frame applies.
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { reportWidth($0) }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: BarLayout.height)
        .background(Self.background,
                    in: UnevenRoundedRectangle(bottomLeadingRadius: 7, bottomTrailingRadius: 7))
        .overlay {
            UnevenRoundedRectangle(bottomLeadingRadius: 7, bottomTrailingRadius: 7)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .coordinateSpace(name: Self.coordinateSpace)
        .onPreferenceChange(BarHitsKey.self) { hits in
            MainActor.assumeIsolated { reportHits(hits) }
        }
    }

    private var sleepMenu: some View {
        @Bindable var sleep = sleep
        return Menu {
            Button("Off", action: sleep.stop).disabled(sleep.label == nil)
            ForEach(SleepBlocker.minuteChoices, id: \.self) { minutes in
                Button(AwakeText.choice(minutes: minutes)) { sleep.start(minutes: minutes) }
            }
            Divider()
            Toggle("Keep display awake", isOn: $sleep.keepsDisplayAwake)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sleep.label == nil ? "moon.zzz" : "cup.and.saucer.fill")
                if let label = sleep.label {
                    Text(label).font(.system(size: 11, weight: .semibold)).monospacedDigit()
                }
            }
            .foregroundStyle(sleep.label == nil ? Color.primary : Color.mint)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, sleep.label == nil ? 0 : 6)
            .frame(minWidth: 24, minHeight: 22)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .barHit("Keep Mac awake")
    }
}
