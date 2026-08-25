import Foundation
import ServiceManagement

/// Менеджер настроек приложения
final class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }

    @Published var keepRunning: Bool {
        didSet {
            UserDefaults.standard.set(keepRunning, forKey: "keepRunning")
        }
    }

    /// Токен для запроса статистики
    var token: String? {
        get { UserDefaults.standard.string(forKey: "botToken") }
        set { UserDefaults.standard.set(newValue, forKey: "botToken") }
    }

    private init() {
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.keepRunning = UserDefaults.standard.object(forKey: "keepRunning") as? Bool ?? true
    }

    /// Применить настройку автозапуска
    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(launchAtLogin ? "register" : "unregister") launch at login: \(error)")
        }
    }

    /// Проверить, зарегистрирован ли автозапуск
    var isLaunchAtLoginRegistered: Bool {
        SMAppService.mainApp.status.rawValue == 2
    }
}
