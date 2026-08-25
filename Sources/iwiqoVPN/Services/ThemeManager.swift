import SwiftUI

/// Тема приложения
enum AppTheme: String, CaseIterable {
    case dark
    case light

    var label: String {
        switch self {
        case .dark: return "Тёмная"
        case .light: return "Светлая"
        }
    }

    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}

/// Палитра цветов для темы
struct ThemePalette {
    // Фон
    let backgroundGradient: [Color]
    let cardBackground: Color
    let cardBorder: Color

    // Текст
    let primaryText: Color
    let secondaryText: Color
    let mutedText: Color

    // Акценты (розовый — одинаковый для обеих тем)
    let accentPrimary: Color
    let accentSecondary: Color
    let accentGradient: [Color]

    // Статусы
    let connectedColor: Color
    let connectingColor: Color
    let errorColor: Color
    let disconnectedColor: Color

    // Свечение кнопки
    let glowConnected: Color
    let glowDisconnected: Color

    // Кольцо кнопки
    let buttonRingGradient: [Color]
    let buttonInnerGradient: [Color]
    let buttonIconGradient: [Color]

    // Divider
    let dividerColor: Color
}

extension AppTheme {
    var palette: ThemePalette {
        switch self {
        case .dark:
            return ThemePalette(
                backgroundGradient: [
                    Color(red: 0.02, green: 0.02, blue: 0.02),
                    Color(red: 0.05, green: 0.05, blue: 0.05),
                ],
                cardBackground: Color.white.opacity(0.04),
                cardBorder: Color.white.opacity(0.08),
                primaryText: .white,
                secondaryText: Color(red: 0.75, green: 0.75, blue: 0.75),
                mutedText: Color(red: 0.55, green: 0.55, blue: 0.55),
                accentPrimary: Color(red: 1.0, green: 0.2, blue: 0.6),
                accentSecondary: Color(red: 0.95, green: 0.1, blue: 0.5),
                accentGradient: [
                    Color(red: 1.0, green: 0.25, blue: 0.65),
                    Color(red: 0.95, green: 0.15, blue: 0.55),
                ],
                connectedColor: Color(red: 0.3, green: 1.0, blue: 0.5),
                connectingColor: Color(red: 1.0, green: 0.75, blue: 0.2),
                errorColor: Color(red: 1.0, green: 0.3, blue: 0.3),
                disconnectedColor: Color(red: 0.55, green: 0.55, blue: 0.55),
                glowConnected: Color(red: 0.3, green: 1.0, blue: 0.5),
                glowDisconnected: Color(red: 1.0, green: 0.2, blue: 0.6),
                buttonRingGradient: [
                    Color(red: 1.0, green: 0.25, blue: 0.65),
                    Color(red: 0.85, green: 0.1, blue: 0.45),
                ],
                buttonInnerGradient: [
                    Color(red: 0.08, green: 0.08, blue: 0.08),
                    Color(red: 0.03, green: 0.03, blue: 0.03),
                ],
                buttonIconGradient: [
                    Color(red: 1.0, green: 0.3, blue: 0.7),
                    Color(red: 0.9, green: 0.15, blue: 0.5),
                ],
                dividerColor: Color.white.opacity(0.08)
            )

        case .light:
            return ThemePalette(
                backgroundGradient: [
                    Color(red: 0.98, green: 0.97, blue: 1.0),
                    Color(red: 0.95, green: 0.93, blue: 0.98),
                ],
                cardBackground: Color.black.opacity(0.03),
                cardBorder: Color.black.opacity(0.06),
                primaryText: Color(red: 0.15, green: 0.12, blue: 0.2),
                secondaryText: Color(red: 0.4, green: 0.38, blue: 0.45),
                mutedText: Color(red: 0.55, green: 0.52, blue: 0.58),
                accentPrimary: Color(red: 1.0, green: 0.25, blue: 0.65),
                accentSecondary: Color(red: 0.88, green: 0.15, blue: 0.52),
                accentGradient: [
                    Color(red: 1.0, green: 0.3, blue: 0.7),
                    Color(red: 0.9, green: 0.2, blue: 0.6),
                ],
                connectedColor: Color(red: 0.15, green: 0.75, blue: 0.35),
                connectingColor: Color(red: 0.95, green: 0.65, blue: 0.1),
                errorColor: Color(red: 0.9, green: 0.2, blue: 0.2),
                disconnectedColor: Color(red: 0.5, green: 0.48, blue: 0.52),
                glowConnected: Color(red: 0.2, green: 0.85, blue: 0.4),
                glowDisconnected: Color(red: 1.0, green: 0.3, blue: 0.7),
                buttonRingGradient: [
                    Color(red: 1.0, green: 0.3, blue: 0.7),
                    Color(red: 0.75, green: 0.12, blue: 0.5),
                ],
                buttonInnerGradient: [
                    Color(red: 1.0, green: 0.98, blue: 1.0),
                    Color(red: 0.96, green: 0.94, blue: 0.99),
                ],
                buttonIconGradient: [
                    Color(red: 1.0, green: 0.3, blue: 0.7),
                    Color(red: 0.85, green: 0.18, blue: 0.55),
                ],
                dividerColor: Color.black.opacity(0.06)
            )
        }
    }
}

/// Менеджер темы — управляет переключением и сохраняет выбор
final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    /// Callback при изменении темы (для AppDelegate)
    var onThemeChange: ((AppTheme) -> Void)?

    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
            onThemeChange?(theme)
        }
    }

    var palette: ThemePalette {
        theme.palette
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.dark.rawValue
        self.theme = AppTheme(rawValue: saved) ?? .dark
    }

    func toggle() {
        theme = theme == .dark ? .light : .dark
    }
}
