import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Theme Mode

enum ThemeMode: String, CaseIterable {
    case classic
    case ink

    var displayName: String {
        switch self {
        case .classic: return "クラシック"
        case .ink: return "Kinetic Ink"
        }
    }

    var iconName: String {
        switch self {
        case .classic: return "circle.lefthalf.filled"
        case .ink: return "paintbrush.pointed.fill"
        }
    }

    var style: ThemeStyle {
        switch self {
        case .classic: return .classic
        case .ink: return .ink
        }
    }
}

// MARK: - Theme Style

struct ThemeStyle {
    // Colors
    let surface: Color
    let surfaceBright: Color
    let surfaceContainerHigh: Color
    let surfaceContainerHighest: Color
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let primaryDim: Color
    let onSurface: Color
    let onSurfaceVariant: Color
    let onPrimary: Color
    let error: Color

    // Fonts
    let headlineFont: Font
    let bodyFont: Font
    let captionFont: Font
    let caption2Font: Font
    let subheadlineFont: Font
    let title2Font: Font
    let title3Font: Font

    // Shape
    let cornerRadius: CGFloat
    let cardCornerRadius: CGFloat
    let chipShape: AnyShape
    let iconFallbackIsCircle: Bool

    // Appearance
    /// テーマが強制するカラースキーム。`nil` はOS設定に従う。
    let colorSchemeOverride: ColorScheme?
    let groupedBackground: Color
    let toolbarBackgroundVisibility: Visibility

    // Feature flags
    let usesScreenTone: Bool
    let hasShadows: Bool

    /// `colorSchemeOverride == .dark` の簡易アクセス（各Viewのスタイリング分岐用）
    var forceDarkMode: Bool { colorSchemeOverride == .dark }

    // Context-specific colors (where ink mapping ≠ classic system color)
    let badgeColor: Color
    let catchUpReadColor: Color
    let catchUpSkipColor: Color
    let heatmapColor: Color
    let onboardingColors: [Color]
    let tutorialColors: (tap: Color, read: Color, skip: Color, undo: Color)
}

extension ThemeStyle {
    static let classic = ThemeStyle(
        surface: .clear,
        surfaceBright: .clear,
        surfaceContainerHigh: Color(.systemFill),
        surfaceContainerHighest: Color(.darkGray),
        primary: .accentColor,
        secondary: .accentColor,
        tertiary: .yellow,
        primaryDim: .accentColor.opacity(0.7),
        onSurface: .primary,
        onSurfaceVariant: .secondary,
        onPrimary: .white,
        error: .red,
        headlineFont: .headline,
        bodyFont: .body,
        captionFont: .caption,
        caption2Font: .caption2,
        subheadlineFont: .subheadline,
        title2Font: .title2.bold(),
        title3Font: .title3.bold(),
        cornerRadius: 8,
        cardCornerRadius: 12,
        chipShape: AnyShape(Capsule()),
        iconFallbackIsCircle: true,
        colorSchemeOverride: nil,
        groupedBackground: Color(UIColor.systemGroupedBackground),
        toolbarBackgroundVisibility: .automatic,
        usesScreenTone: false,
        hasShadows: true,
        badgeColor: .red,
        catchUpReadColor: .green,
        catchUpSkipColor: .orange,
        heatmapColor: .green,
        onboardingColors: [.blue, .green, .orange, .purple],
        tutorialColors: (tap: .blue, read: .green, skip: .orange, undo: .secondary)
    )

    static let ink = ThemeStyle(
        surface: Color(hex: "0e0e0e"),
        surfaceBright: Color(hex: "1a1a1a"),
        surfaceContainerHigh: Color(hex: "212121"),
        surfaceContainerHighest: Color(hex: "262626"),
        primary: Color(hex: "ff8d8d"),
        secondary: Color(hex: "00eefc"),
        tertiary: Color(hex: "ffeb92"),
        primaryDim: Color(hex: "cc6b6b"),
        onSurface: .white,
        onSurfaceVariant: Color(hex: "a0a0a0"),
        onPrimary: Color(hex: "0e0e0e"),
        error: Color(hex: "ff7351"),
        headlineFont: .system(size: 15, weight: .black),
        bodyFont: .system(size: 15, weight: .bold),
        captionFont: .system(size: 12, weight: .bold),
        caption2Font: .system(size: 10),
        subheadlineFont: .system(size: 14, weight: .bold),
        title2Font: .system(size: 22, weight: .black),
        title3Font: .system(size: 18, weight: .black),
        cornerRadius: 4,
        cardCornerRadius: 6,
        chipShape: AnyShape(RoundedRectangle(cornerRadius: 4)),
        iconFallbackIsCircle: false,
        colorSchemeOverride: .dark,
        groupedBackground: Color(hex: "0e0e0e"),
        toolbarBackgroundVisibility: .visible,
        usesScreenTone: true,
        hasShadows: false,
        badgeColor: Color(hex: "ff8d8d"),
        catchUpReadColor: Color(hex: "00eefc"),
        catchUpSkipColor: Color(hex: "ffeb92"),
        heatmapColor: Color(hex: "ff8d8d"),
        onboardingColors: [Color(hex: "ff8d8d"), Color(hex: "00eefc"), Color(hex: "ffeb92"), Color(hex: "ff8d8d")],
        tutorialColors: (tap: Color(hex: "00eefc"), read: Color(hex: "00eefc"), skip: Color(hex: "ffeb92"), undo: Color(hex: "a0a0a0"))
    )
}

// MARK: - Theme Manager

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var mode: ThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "appTheme") }
    }

    private init() {
        self.mode = ThemeMode(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "classic") ?? .classic
    }

    var style: ThemeStyle { mode.style }
}

// MARK: - InkTheme Constants (for ink-only structural code)

enum InkTheme {
    static let surface = Color(hex: "0e0e0e")
    static let surfaceBright = Color(hex: "1a1a1a")
    static let surfaceContainerHigh = Color(hex: "212121")
    static let surfaceContainerHighest = Color(hex: "262626")
    static let primary = Color(hex: "ff8d8d")
    static let secondary = Color(hex: "00eefc")
    static let tertiary = Color(hex: "ffeb92")
    static let primaryDim = Color(hex: "cc6b6b")
    static let onSurface = Color.white
    static let onSurfaceVariant = Color(hex: "a0a0a0")
    static let onPrimary = Color(hex: "0e0e0e")
    static let cornerRadius: CGFloat = 4
    static let cardCornerRadius: CGFloat = 6
    static let spacingMD: CGFloat = 16
    static let spacingSM: CGFloat = 8
    static let spacingLG: CGFloat = 24
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

// MARK: - Themed Navigation Style

extension View {
    func themedNavigationStyle() -> some View {
        let style = ThemeManager.shared.style
        return self
            .scrollContentBackground(.hidden)
            .background(style.groupedBackground)
            .toolbarBackground(style.toolbarBackgroundVisibility, for: .navigationBar)
            .toolbarColorScheme(style.colorSchemeOverride, for: .navigationBar)
    }
}

// MARK: - Drag Preview Cell

struct DragPreviewCell: View {
    let entry: MangaEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let imageData = entry.imageData, let image = imageData.toSwiftUIImage() {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.fromName(entry.iconColor))
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay {
                        Text(entry.name)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(4)
                    }
            }
            Text(entry.name)
                .font(.caption2)
                .lineLimit(1)
        }
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
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
