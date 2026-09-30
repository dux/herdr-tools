import AppKit
import SwiftUI
import PastirCore

enum SFSymbols {
    static let all: [String] = load()

    private static func load() -> [String] {
        let base = "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/"
        if let plist = NSDictionary(contentsOfFile: base + "name_availability.plist"),
           let symbols = plist["symbols"] as? [String: Any], !symbols.isEmpty {
            return symbols.keys.sorted()
        }
        if let names = NSArray(contentsOfFile: base + "symbol_order.plist") as? [String], !names.isEmpty {
            return names
        }
        return ["terminal", "arrow.triangle.branch", "chevron.left.forwardslash.chevron.right", "folder", "app"]
    }
}

struct SymbolPicker: View {
    @Binding var symbol: String
    let dismiss: () -> Void
    @State private var query = ""

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search 9,000+ symbols", text: $query)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 6)], spacing: 6) {
                    ForEach(matches, id: \.self) { name in
                        Button {
                            symbol = name
                            dismiss()
                        } label: {
                            Image(systemName: name)
                                .font(.system(size: 15))
                                .frame(width: 32, height: 32)
                                .background(symbol == name ? Color.accentColor.opacity(0.25) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help(name)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .frame(width: 380, height: 340)
    }

    private var matches: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Array(SFSymbols.all.prefix(300)) }
        return Array(SFSymbols.all.lazy
            .filter { $0.localizedCaseInsensitiveContains(trimmed) }
            .prefix(300))
    }
}
