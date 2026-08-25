import SwiftUI

/// Главная view — содержимое popover окна
struct MainView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var botService = BotService.shared
    @State private var showSettings = false
    @State private var showSetup = false

    var body: some View {
        ZStack {
            // Фон
            LinearGradient(
                colors: themeManager.palette.backgroundGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if showSettings {
                SettingsView(showSettings: $showSettings)
                    .environmentObject(themeManager)
                    .environmentObject(SettingsManager.shared)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else if showSetup || !botService.hasConfig {
                // Экран получения конфига
                SetupView(showSetup: $showSetup)
                    .environmentObject(themeManager)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                VStack(spacing: 0) {
                    // Шапка с логотипом
                    HeaderView()
                        .padding(.top, 16)

                    // Центральная зона с кнопкой
                    ConnectionView()
                        .padding(.top, 8)

                    // Статистика (если подключён)
                    if vpnManager.status == .connected {
                        StatsView()
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    // Выбор сервера
                    ServerSelectionView()
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    // Футер
                    FooterView(showSettings: $showSettings, showSetup: $showSetup)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }

        }
        .frame(width: 340, height: currentHeight)
        .animation(.easeInOut(duration: 0.25), value: showSettings)
        .animation(.easeInOut(duration: 0.3), value: vpnManager.status)
        .animation(.easeInOut(duration: 0.3), value: themeManager.theme)
        .animation(.easeInOut(duration: 0.25), value: showSetup)
    }

    /// Текущая высота окна
    private var currentHeight: CGFloat {
        if showSettings || showSetup || !botService.hasConfig {
            return 520
        }
        return vpnManager.status == .connected ? 520 : 420
    }
}

// MARK: - Header

struct HeaderView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        let p = themeManager.palette

        VStack(spacing: 6) {
            // Логотип iwiqo
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: p.accentGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("iwiqo")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: p.accentGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            // Текст статуса
            Text(vpnManager.status.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(statusColor)
        }
    }

    private var statusColor: Color {
        let p = themeManager.palette
        switch vpnManager.status {
        case .connected: return p.connectedColor
        case .connecting, .disconnecting: return p.connectingColor
        case .error: return p.errorColor
        case .disconnected: return p.disconnectedColor
        }
    }
}

// MARK: - Connection Button

struct ConnectionView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var spinRotation = false

    var body: some View {
        let p = themeManager.palette

        VStack(spacing: 16) {
            // Большая круглая кнопка
            Button(action: {
                vpnManager.toggle()
            }) {
                ZStack {
                    // Внешнее свечение
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    glowColor.opacity(0.4),
                                    glowColor.opacity(0.0),
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)

                    // Кольцо
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: p.buttonRingGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 100, height: 100)

                    // Внутренний круг
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: p.buttonInnerGradient,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 88, height: 88)

                    // Иконка питания
                    Group {
                        if vpnManager.status.isTransitioning {
                            // Спиннер при подключении/отключении
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: p.buttonIconGradient,
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .rotationEffect(.degrees(spinRotation ? 360 : 0))
                                .animation(
                                    .linear(duration: 1.0).repeatForever(autoreverses: false),
                                    value: spinRotation
                                )
                        } else {
                            // Иконка power / checkmark
                            Image(systemName: vpnManager.status == .connected ? "checkmark" : "power")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: p.buttonIconGradient,
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .frame(width: 140, height: 140)
            }
            .buttonStyle(.plain)
            .disabled(vpnManager.status.isTransitioning)
            .onChange(of: vpnManager.status.isTransitioning) { transitioning in
                if transitioning {
                    spinRotation = true
                } else {
                    spinRotation = false
                }
            }

            // Текст под кнопкой
            Text(buttonLabel)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(p.secondaryText)
        }
    }

    private var buttonLabel: String {
        switch vpnManager.status {
        case .connected: return "Нажмите для отключения"
        case .connecting: return "Устанавливаем соединение…"
        case .disconnecting: return "Отключаем…"
        case .disconnected: return "Нажмите для подключения"
        case .error: return "Попробовать снова"
        }
    }

    private var glowColor: Color {
        vpnManager.status == .connected
            ? themeManager.palette.glowConnected
            : themeManager.palette.glowDisconnected
    }
}

// MARK: - Stats

struct StatsView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var remainingGb: String = "—"

    var body: some View {
        let p = themeManager.palette

        VStack(spacing: 10) {
            StatRow(icon: "clock", label: "Время", value: vpnManager.connectionDuration)

            Divider()
                .background(p.dividerColor)

            StatRow(icon: "arrow.up", label: "Отправлено", value: vpnManager.dataSentFormatted)

            Divider()
                .background(p.dividerColor)

            StatRow(icon: "chart.bar.doc.horizontal", label: "Остаток", value: remainingGb)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(p.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(p.cardBorder, lineWidth: 1)
                )
        )
        .onAppear {
            loadRemaining()
        }
    }

    private func loadRemaining() {
        guard let token = SettingsManager.shared.token else { return }
        BotService.shared.fetchStats(token: token) { result in
            switch result {
            case .success(let stats):
                remainingGb = "\(String(format: "%.1f", stats.remainingGb)) ГБ"
            case .failure:
                remainingGb = "—"
            }
        }
    }
}

struct StatRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    let icon: String
    let label: String
    let value: String

    var body: some View {
        let p = themeManager.palette

        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(p.accentPrimary)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(p.secondaryText)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(p.primaryText.opacity(0.9))
        }
    }
}

// MARK: - Server Selection

struct ServerSelectionView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isExpanded = false

    var body: some View {
        let p = themeManager.palette

        VStack(alignment: .leading, spacing: 8) {
            Text("Сервер")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundColor(p.mutedText)
                .tracking(1)

            // Кнопка выбора сервера
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(vpnManager.selectedServer?.flag ?? "🌐")
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vpnManager.selectedServer?.name ?? "Выбрать сервер")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(p.primaryText)
                        Text(vpnManager.selectedServer?.location ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(p.mutedText)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(p.accentPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
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
            .disabled(vpnManager.status == .connected || vpnManager.status.isTransitioning)
            .opacity(vpnManager.status == .connected ? 0.5 : 1.0)

            // Раскрытый список серверов
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(vpnManager.servers) { server in
                        Button(action: {
                            vpnManager.selectedServer = server
                            withAnimation(.spring(response: 0.3)) {
                                isExpanded = false
                            }
                        }) {
                            HStack {
                                Text(server.flag)
                                    .font(.system(size: 18))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(server.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(p.primaryText)
                                    Text(server.location)
                                        .font(.system(size: 10))
                                        .foregroundColor(p.mutedText)
                                }

                                Spacer()

                                if vpnManager.selectedServer?.id == server.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(p.accentPrimary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        vpnManager.selectedServer?.id == server.id
                                            ? p.accentPrimary.opacity(0.12)
                                            : Color.clear
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(p.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(p.cardBorder, lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Footer

struct FooterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var showSettings: Bool
    @Binding var showSetup: Bool

    var body: some View {
        let p = themeManager.palette

        HStack(spacing: 16) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showSettings = true
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text("Настройки")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(p.accentPrimary)
            }
            .buttonStyle(.plain)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showSetup = true
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 11))
                    Text("Конфиг")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(p.mutedText)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
}

// MARK: - Close Button (traffic light style)

struct CloseButton: View {
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            NotificationCenter.default.post(name: .iwiqoClosePopover, object: nil)
        }) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.26, blue: 0.21))
                    .frame(width: 12, height: 12)

                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(isHovered ? 1 : 0)
                    .rotationEffect(.degrees(isHovered ? 0 : -90))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            }
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .buttonStyle(.plain)
        .help("Закрыть")
    }
}

extension Notification.Name {
    static let iwiqoClosePopover = Notification.Name("iwiqoClosePopover")
}
