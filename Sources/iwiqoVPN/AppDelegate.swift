import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var invisibleWindow: NSWindow?
    private var vpnManager = VPNManager.shared
    private var themeManager = ThemeManager.shared
    private var settingsManager = SettingsManager.shared
    private var eventMonitor: EventMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Показываем иконку в Dock + menu bar
        NSApp.setActivationPolicy(.regular)
        NSApp.activationPolicy()

        // Проверяем наличие конфига при старте
        BotService.shared.refreshConfigStatus()

        // Запрещаем автоматическое завершение
        ProcessInfo.processInfo.disableAutomaticTermination("iwiqo-running")

        // Создаём невидимое окно чтобы macOS не завершала приложение
        let invisibleWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        invisibleWindow.isOpaque = false
        invisibleWindow.backgroundColor = .clear
        invisibleWindow.canHide = false
        self.invisibleWindow = invisibleWindow

        // Создаём status item
        statusItem = NSStatusBar.system.statusItem(withLength: 24)
        statusItem.isVisible = true
        statusItem.autosaveName = "iwiqo-status-item"

        // Создаём popover с нашим UI
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 420)
        popover.behavior = .applicationDefined
        popover.animates = true

        let contentView = MainView()
            .environmentObject(vpnManager)
            .environmentObject(themeManager)
        popover.contentViewController = NSHostingController(rootView: contentView)

        // Настройка иконки в menu bar
        if let button = statusItem.button {
            updateMenuBarIcon()
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Монитор кликов вне popover для его закрытия
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] in
            self?.closePopoverIfNeeded()
        }

        // Подписываемся на изменения статуса VPN для обновления иконки и размера
        vpnManager.onStatusChange = { [weak self] status in
            DispatchQueue.main.async {
                self?.updateMenuBarIcon()
                self?.updatePopoverSize(connected: status == .connected)
            }
        }

        // Подписываемся на изменения темы для обновления иконки
        themeManager.onThemeChange = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateMenuBarIcon()
            }
        }

        // Показываем popover при первом запуске чтобы пользователь заметил приложение
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showPopover()
            self?.showLaunchNotification()
        }

        // Слушатель для закрытия popover из SwiftUI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClosePopover),
            name: .iwiqoClosePopover,
            object: nil
        )
    }

    @objc private func handleClosePopover() {
        statusItem.menu = nil
        quitApplication()
    }

    /// Полностью закрыть приложение
    func quitApplication() {
        if vpnManager.status == .connected {
            vpnManager.disconnect()
        }
        // Обходим keepRunning — пользователь явно хочет выйти
        settingsManager.keepRunning = false
        NSApp.terminate(nil)
    }

    /// При повторном открытии через Программы — показать popover
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem.isVisible = true
        showPopover()
        return true
    }

    /// Не завершать приложение при закрытии окна
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Показать уведомление что приложение запущено
    private func showLaunchNotification() {
        let notification = NSUserNotification()
        notification.title = "iwiqo"
        notification.informativeText = "VPN готов к работе"
        NSUserNotificationCenter.default.deliver(notification)
    }

    /// Обработка закрытия окна — если "keepRunning" включён, не выходим
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if settingsManager.keepRunning {
            // Просто закрываем popover, приложение остаётся в menu bar
            closePopoverIfNeeded()
            return .terminateCancel
        }
        return .terminateNow
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }

        let isConnected = vpnManager.status == .connected

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let baseImage = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "iwiqo")
        guard let baseImage = baseImage else { return }
        let symbolImage = baseImage.withSymbolConfiguration(config) ?? baseImage

        if isConnected {
            // Розовая иконка — красим через bitmap
            let tinted = NSImage(size: symbolImage.size)
            tinted.lockFocus()
            symbolImage.draw(in: NSRect(origin: .zero, size: symbolImage.size))
            NSColor(red: 1.0, green: 0.3, blue: 0.7, alpha: 1.0).setFill()
            NSRect(origin: .zero, size: symbolImage.size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            tinted.isTemplate = false
            button.image = tinted
        } else {
            // Системная адаптивная иконка — template режим
            symbolImage.isTemplate = true
            button.image = symbolImage
        }
    }

    /// Обновить размер popover в зависимости от статуса (плавная анимация)
    private func updatePopoverSize(connected: Bool) {
        let targetHeight: CGFloat = connected ? 520 : 420
        let currentSize = popover.contentSize
        let targetSize = NSSize(width: 340, height: targetHeight)

        // Плавная анимация через steps
        let steps = 20
        let duration = 0.35
        let heightDiff = targetHeight - currentSize.height

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (duration / Double(steps)) * Double(i)) {
                let progress = Double(i) / Double(steps)
                // easeInOut кривая
                let eased = progress < 0.5
                    ? 2 * progress * progress
                    : 1 - pow(-2 * progress + 2, 2) / 2
                let animatedHeight = currentSize.height + heightDiff * eased
                self.popover.contentSize = NSSize(width: 340, height: animatedHeight)
            }
        }
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopoverIfNeeded()
        } else {
            showPopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let connectTitle = vpnManager.status == .connected ? "Отключиться" : "Подключиться"
        let connectItem = NSMenuItem(title: connectTitle, action: #selector(toggleVPN), keyEquivalent: "")
        connectItem.target = self
        menu.addItem(connectItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Закрыть полностью", action: #selector(handleClosePopover), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    @objc private func toggleVPN() {
        vpnManager.toggle()
        // Сбрасываем menu чтобы следующий клик работал нормально
        statusItem.menu = nil
    }

    private func showPopover() {
        statusItem.isVisible = true
        if let button = statusItem.button {
            // Обновляем content view (для актуальной темы)
            let contentView = MainView()
                .environmentObject(vpnManager)
                .environmentObject(themeManager)
            popover.contentViewController = NSHostingController(rootView: contentView)

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func closePopoverIfNeeded() {
        if popover.isShown {
            popover.close()
            eventMonitor?.stop()
        }
    }
}

/// Монитор глобальных событий (клики вне popover)
final class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: () -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping () -> Void) {
        self.mask = mask
        self.handler = handler
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            self?.handler()
        })
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
