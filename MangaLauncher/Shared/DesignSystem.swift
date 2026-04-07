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

    // Spacing
    let spacingSM: CGFloat
    let spacingMD: CGFloat
    let spacingLG: CGFloat

    // Tab bar
    let tabSpacing: CGFloat
    let tabItemSpacing: CGFloat
    let tabFont: (_ isSelected: Bool) -> Font
    let tabItemHeight: CGFloat?
    let tabUnreadDotSize: CGFloat
    let tabUnderlineHeight: CGFloat
    let tabUnderlineCornerRadius: CGFloat
    let tabSelectedRotation: Double
    let tabSelectedScale: CGFloat
    let tabShowsTodayCircle: Bool

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
        spacingSM: 8,
        spacingMD: 16,
        spacingLG: 24,
        tabSpacing: 0,
        tabItemSpacing: 4,
        tabFont: { _ in .headline },
        tabItemHeight: nil,
        tabUnreadDotSize: 5,
        tabUnderlineHeight: 2,
        tabUnderlineCornerRadius: 0,
        tabSelectedRotation: 0,
        tabSelectedScale: 1.0,
        tabShowsTodayCircle: true,
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
        spacingSM: 8,
        spacingMD: 16,
        spacingLG: 24,
        tabSpacing: 2,
        tabItemSpacing: 2,
        tabFont: { isSelected in .system(size: isSelected ? 26 : 18, weight: .black) },
        tabItemHeight: 52,
        tabUnreadDotSize: 6,
        tabUnderlineHeight: 3,
        tabUnderlineCornerRadius: 2,
        tabSelectedRotation: -3,
        tabSelectedScale: 1.1,
        tabShowsTodayCircle: false,
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

// MARK: - Speech Bubble Button Style

struct SpeechBubbleButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    private var ink: ThemeStyle { .ink }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isPrimary ? ink.onPrimary : ink.onSurface)
            .padding(.horizontal, ink.spacingLG)
            .padding(.vertical, ink.spacingMD)
            .background(
                isPrimary
                    ? AnyShapeStyle(LinearGradient(colors: [ink.primary, ink.primaryDim], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(ink.surfaceBright)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Conditional View Modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
