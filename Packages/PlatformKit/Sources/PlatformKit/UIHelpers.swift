import SwiftUI

// MARK: - Live Blur Background (UIKit)

#if canImport(UIKit)
public struct VisualEffectBlur: UIViewRepresentable {
    public var style: UIBlurEffect.Style

    public init(style: UIBlurEffect.Style) {
        self.style = style
    }

    public func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    public func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
#endif

// MARK: - Cross-platform Colors

extension Color {
    public static var platformBackground: Color {
        #if canImport(UIKit)
        Color(.systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    public static var platformFill: Color {
        #if canImport(UIKit)
        Color(.systemFill)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    public static var platformGray5: Color {
        #if canImport(UIKit)
        Color(.systemGray5)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }

    public static func fromName(_ name: String) -> Color {
        switch name {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "teal": .teal
        default: .blue
        }
    }
}
