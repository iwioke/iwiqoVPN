import SwiftUI

/// Экран настроек
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Binding var showSettings: Bool

    var body: some View {
        ZStack {
            // Фон
            LinearGradient(
                colors: themeManager.palette.backgroundGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Шапка с кнопкой "Назад"
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSettings = false
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Назад")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(themeManager.palette.accentPrimary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Настройки")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.palette.primaryText)

                    Spacer()

                    // Пустой spacer для центрирования
                    Color.clear
                        .frame(width: 50, height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // Содержимое настроек
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Тема
                        SettingsSection(title: "Внешний вид", icon: "paintbrush.fill") {
                            ThemeSelector()
                        }

                        // Автозапуск
                        SettingsSection(title: "Система", icon: "gearshape.fill") {
                            ToggleRow(
                                icon: "power.circle",
                                title: "Запускать с Mac",
                                subtitle: "Автозапуск при включении компьютера",
                                isOn: $settingsManager.launchAtLogin
                            )

                            ToggleRow(
                                icon: "pin.circle",
                                title: "Держать запущенным",
                                subtitle: "Приложение остаётся в menu bar",
                                isOn: $settingsManager.keepRunning
                            )
                        }

                        // О приложении
                        SettingsSection(title: "О приложении", icon: "info.circle.fill") {
                            AboutRow()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .padding(.top, 20)
        }
        .frame(width: 340, height: 460)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager

    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Заголовок секции
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.palette.accentPrimary)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundColor(themeManager.palette.mutedText)
                    .tracking(1)
            }

            // Содержимое
            VStack(spacing: 0) {
                content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeManager.palette.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(themeManager.palette.cardBorder, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Theme Selector

struct ThemeSelector: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 10) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        themeManager.theme = theme
                    }
                }) {
                    HStack(spacing: 12) {
                        // Иконка темы
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: theme == .dark
                                            ? [Color(red: 0.15, green: 0.07, blue: 0.18),
                                               Color(red: 0.08, green: 0.04, blue: 0.12)]
                                            : [Color(red: 0.98, green: 0.97, blue: 1.0),
                                               Color(red: 0.95, green: 0.93, blue: 0.98)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: theme.icon)
                                .font(.system(size: 16))
                                .foregroundColor(themeManager.palette.accentPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(theme.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(themeManager.palette.primaryText)

                            Text(theme == .dark ? "Розово-чёрная" : "Розово-белая")
                                .font(.system(size: 11))
                                .foregroundColor(themeManager.palette.mutedText)
                        }

                        Spacer()

                        // Индикатор выбора
                        if themeManager.theme == theme {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(themeManager.palette.accentPrimary)
                        } else {
                            Image(systemName: "circle")
                                .font(.system(size: 20))
                                .foregroundColor(themeManager.palette.mutedText.opacity(0.4))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Иконка
            ZStack {
                Circle()
                    .fill(themeManager.palette.accentPrimary.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.palette.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(themeManager.palette.primaryText)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.palette.mutedText)
            }

            Spacer()

            // Кастомный переключатель
            Toggle("", isOn: $isOn)
                .toggleStyle(CustomToggleStyle())
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Toggle

struct CustomToggleStyle: ToggleStyle {
    @EnvironmentObject var themeManager: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        let palette = themeManager.palette

        HStack {
            configuration.label

            Button(action: {
                configuration.isOn.toggle()
            }) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(configuration.isOn ? palette.accentPrimary : palette.cardBorder)
                    .frame(width: 40, height: 22)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: configuration.isOn ? 9 : -9)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isOn)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - About Row

struct AboutRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 12) {
            // Логотип
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: themeManager.palette.accentGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("iwiqo")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: themeManager.palette.accentGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            Text("Версия 1.0.0")
                .font(.system(size: 12))
                .foregroundColor(themeManager.palette.mutedText)

            Text("© 2026 iwiqo. Все права защищены.")
                .font(.system(size: 11))
                .foregroundColor(themeManager.palette.mutedText.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
