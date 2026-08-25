import SwiftUI

/// Экран получения конфига через Telegram бота
struct SetupView: View {
    @Binding var showSetup: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var botService = BotService.shared
    @State private var token = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false

    var body: some View {
        let p = themeManager.palette

        VStack(spacing: 0) {
            // Шапка с кнопкой "Назад"
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSetup = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Назад")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(p.accentPrimary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Контент
            VStack(spacing: 20) {
                // Иконка
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [p.accentPrimary.opacity(0.15), p.accentPrimary.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: p.accentGradient,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .padding(.top, 8)

                // Заголовок
                VStack(spacing: 6) {
                    Text("Подключение к iwiqo")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(p.primaryText)

                    if botService.hasConfig {
                        // Конфиг уже есть — показываем зелёную надпись
                        Text("Конфиг установлен")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(p.connectedColor)
                    } else {
                        Text("Получите токен в Telegram боте")
                            .font(.system(size: 13))
                            .foregroundColor(p.secondaryText)
                    }
                }

                // Если конфиг уже есть — показываем статус
                if botService.hasConfig {
                    // Зелёный блок "Всё окей"
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                            Text("VPN настроен и готов")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(p.connectedColor)

                        Text("Нажми «Готово» чтобы вернуться и подключиться")
                            .font(.system(size: 12))
                            .foregroundColor(p.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(p.connectedColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(p.connectedColor.opacity(0.3), lineWidth: 1)
                            )
                    )

                    // Кнопка "Готово"
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSetup = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Готово")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: p.accentGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else {
                // Шаг 1: Открыть бота
                VStack(alignment: .leading, spacing: 8) {
                    Text("Шаг 1")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundColor(p.mutedText)
                        .tracking(1)

                    Button(action: {
                        BotService.shared.openBot()
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 14))
                            Text("Открыть бота")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(p.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(p.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(p.cardBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Шаг 2: Ввести токен
                VStack(alignment: .leading, spacing: 8) {
                    Text("Шаг 2")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundColor(p.mutedText)
                        .tracking(1)

                    VStack(spacing: 10) {
                        // Поле ввода токена
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.system(size: 12))
                                .foregroundColor(p.mutedText)

                            TextField("Вставьте токен", text: $token)
                                .font(.system(size: 13))
                                .foregroundColor(p.primaryText)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(p.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(p.cardBorder, lineWidth: 1)
                                )
                        )

                        // Кнопка "Подключить"
                        Button(action: {
                            downloadConfig()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                }
                                Text(isLoading ? "Подключаем…" : "Подключить")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: p.accentGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .disabled(token.isEmpty || isLoading)
                        .opacity(token.isEmpty ? 0.5 : 1.0)
                    }
                }

                // Ошибка
                if showError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text(errorMessage)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(p.errorColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(p.errorColor.opacity(0.1))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Успех
                if showSuccess {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Конфиг сохранён! Можно подключаться.")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(p.connectedColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(p.connectedColor.opacity(0.1))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                } // конец else
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    /// Скачать конфиг по токену
    private func downloadConfig() {
        isLoading = true
        showError = false
        showSuccess = false

        print("🔍 Начинаю загрузку конфига для токена: \(token)")

        BotService.shared.downloadConfig(token: token) { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let config):
                    print("✅ Конфиг получен, длина: \(config.count)")
                    do {
                        let path = try BotService.shared.saveConfig(config)
                        print("✅ Конфиг сохранён: \(path)")
                        // Сохраняем токен для будущих запросов статистики
                        SettingsManager.shared.token = token
                        // Обновляем реактивный статус
                        botService.refreshConfigStatus()
                        // Сразу возвращаемся на главный экран
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSetup = false
                        }
                    } catch {
                        print("❌ Ошибка сохранения: \(error)")
                        errorMessage = "Не удалось сохранить: \(error.localizedDescription)"
                        showError = true
                    }

                case .failure(let error):
                    print("❌ Ошибка загрузки: \(error)")
                    errorMessage = "Ошибка: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}
