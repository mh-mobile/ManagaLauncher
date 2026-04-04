import SwiftUI

// MARK: - Kinetic Ink & Screen-Tone Design System

enum InkTheme {
    // MARK: Colors - Ink & Paper
    static let surface = Color(hex: "0e0e0e")
    static let surfaceDim = Color(hex: "0e0e0e")
    static let surfaceBright = Color(hex: "1a1a1a")
    static let surfaceContainerLow = Color(hex: "1a1a1a")
    static let surfaceContainerHigh = Color(hex: "212121")
    static let surfaceContainerHighest = Color(hex: "262626")

    // MARK: Electric Accents
    static let primary = Color(hex: "ff8d8d")        // Neon Red
    static let secondary = Color(hex: "00eefc")       // Neon Blue
    static let tertiary = Color(hex: "ffeb92")         // Vintage Yellow
    static let primaryDim = Color(hex: "cc6b6b")

    // MARK: Text Colors
    static let onSurface = Color.white
    static let onSurfaceVariant = Color(hex: "a0a0a0")
    static let onPrimary = Color(hex: "0e0e0e")

    // MARK: Error
    static let error = Color(hex: "ff7351")

    // MARK: Roundedness
    static let cornerRadius: CGFloat = 4
    static let cardCornerRadius: CGFloat = 6
    static let bubbleCornerRadius: CGFloat = 16

    // MARK: Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Screen-Tone Pattern

struct ScreenTonePattern: View {
    var opacity: Double = 0.05
    var dotSize: CGFloat = 2
    var spacing: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, to: size.width, by: spacing) {
                for y in stride(from: 0, to: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                }
            }
        }
    }
}

// MARK: - Speed Lines Background

struct SpeedLinesBackground: View {
    var lineCount: Int = 30
    var color: Color = .white.opacity(0.03)

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for i in 0..<lineCount {
                let angle = Double(i) * (360.0 / Double(lineCount)) * .pi / 180
                let endX = center.x + cos(angle) * max(size.width, size.height)
                let endY = center.y + sin(angle) * max(size.width, size.height)
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(x: endX, y: endY))
                context.stroke(path, with: .color(color), lineWidth: 1)
            }
        }
    }
}

// MARK: - Ink Card Style

struct InkCardModifier: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: InkTheme.cardCornerRadius)
                    .fill(elevated ? InkTheme.surfaceContainerHighest : InkTheme.surfaceContainerHigh)
            )
    }
}

extension View {
    func inkCard(elevated: Bool = false) -> some View {
        modifier(InkCardModifier(elevated: elevated))
    }
}

// MARK: - Speech Bubble Button Style

struct SpeechBubbleButtonStyle: ButtonStyle {
    var isPrimary: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isPrimary ? InkTheme.onPrimary : InkTheme.onSurface)
            .padding(.horizontal, InkTheme.spacingLG)
            .padding(.vertical, InkTheme.spacingMD)
            .background(
                isPrimary
                    ? AnyShapeStyle(LinearGradient(colors: [InkTheme.primary, InkTheme.primaryDim], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(InkTheme.surfaceBright)
            )
            .clipShape(RoundedRectangle(cornerRadius: InkTheme.bubbleCornerRadius))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
