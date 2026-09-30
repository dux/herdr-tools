import Foundation

public enum HerdrPanes {
    // Mirrors hfolder: the focused pane's foreground_cwd falls back to cwd.
    public static func focusedFolder(json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let panes = result["panes"] as? [[String: Any]],
              let focused = panes.first(where: { $0["focused"] as? Bool == true }) else { return nil }
        return (focused["foreground_cwd"] as? String) ?? (focused["cwd"] as? String)
    }
}
