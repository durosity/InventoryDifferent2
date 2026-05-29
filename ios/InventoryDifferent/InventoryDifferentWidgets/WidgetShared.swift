import SwiftUI
import WidgetKit

// Shared helpers used across all widget views

extension View {
    @ViewBuilder
    func widgetBackground<Background: View>(@ViewBuilder background: () -> Background) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget, content: background)
        } else {
            self.background(background())
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

struct RainbowDot: View {
    var size: CGFloat = 12
    var body: some View {
        Circle()
            .fill(AngularGradient(colors: [.red, .yellow, .green, .blue, .red], center: .center))
            .frame(width: size, height: size)
    }
}
