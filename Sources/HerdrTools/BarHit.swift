import SwiftUI

/// Horizontal extent of a bar item, reported by BarView so the controller can place
/// tooltips and route right-clicks without mirroring the layout.
struct BarHit: Equatable, Sendable {
    let text: String
    let range: ClosedRange<CGFloat>
    let hasContextMenu: Bool
}

struct BarHitsKey: PreferenceKey {
    static let defaultValue: [BarHit] = []

    static func reduce(value: inout [BarHit], nextValue: () -> [BarHit]) {
        value += nextValue()
    }
}

extension View {
    func barHit(_ text: String, hasContextMenu: Bool = false) -> some View {
        background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(BarView.coordinateSpace))
                Color.clear.preference(key: BarHitsKey.self,
                                       value: [BarHit(text: text, range: frame.minX...frame.maxX,
                                                      hasContextMenu: hasContextMenu)])
            }
        }
    }
}
