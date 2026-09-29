enum TargetApp: String, CaseIterable, Identifiable {
    case herdr, fork, vscode

    var id: Self { self }
    var title: String {
        switch self {
        case .herdr: "Herdr"
        case .fork: "Fork"
        case .vscode: "VS Code"
        }
    }
    var symbol: String {
        switch self {
        case .herdr: "terminal"
        case .fork: "arrow.triangle.branch"
        case .vscode: "chevron.left.forwardslash.chevron.right"
        }
    }
    var bundleID: String {
        switch self {
        case .herdr: "com.apple.Terminal"
        case .fork: "com.DanPristupov.Fork"
        case .vscode: "com.microsoft.VSCode"
        }
    }
}
