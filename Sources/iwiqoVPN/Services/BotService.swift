import Foundation
import AppKit

/// Сервис для получения конфига через Telegram бота
final class BotService: ObservableObject {

    static let shared = BotService()

    /// Конфиг установлен? (реактивное свойство)
    @Published var hasConfig: Bool = false

    /// Username бота
    private let botUsername = "iwiqo_vpn_bot"

    /// URL веб-сервера бота для получения конфига
    private let serverURL = "http://138.68.107.226:8080"

    /// Проверить, установлен ли Telegram
    var isTelegramInstalled: Bool {
        let url = URL(string: "tg://")!
        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }

    /// Открыть бота в Telegram
    func openBot() {
        // Пытаемся открыть через Telegram app
        let tgURL = "tg://resolve?domain=\(botUsername)"
        if let url = URL(string: tgURL) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Открыть ссылку в браузере (запасной вариант)
    func openBotInBrowser() {
        let webURL = "https://t.me/\(botUsername)"
        if let url = URL(string: webURL) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Скачать конфиг по токену
    func downloadConfig(token: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Очищаем токен от пробелов и переносов
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty,
              let url = URL(string: "\(serverURL)/config/\(cleanToken)") else {
            completion(.failure(BotError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data,
                  let config = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    completion(.failure(BotError.invalidResponse))
                }
                return
            }

            // Проверяем что это WireGuard конфиг
            if config.contains("[Interface]") && config.contains("[Peer]") {
                DispatchQueue.main.async {
                    completion(.success(config))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(BotError.invalidConfig))
                }
            }
        }.resume()
    }

    /// Сохранить конфиг в файл
    func saveConfig(_ config: String) throws -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configDir = home.appendingPathComponent(".config/wireguard")

        // Создаём директорию если нет
        try FileManager.default.createDirectory(
            at: configDir,
            withIntermediateDirectories: true
        )

        let configPath = configDir.appendingPathComponent("iwiqo.conf").path
        try config.write(toFile: configPath, atomically: true, encoding: .utf8)

        // Устанавливаем права 600 (только владелец может читать)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: configPath
        )

        // Обновляем реактивный статус
        refreshConfigStatus()

        return configPath
    }

    /// Обновить статус конфига
    func refreshConfigStatus() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let path = home.appendingPathComponent(".config/wireguard/iwiqo.conf").path
        DispatchQueue.main.async {
            self.hasConfig = FileManager.default.fileExists(atPath: path)
        }
    }

    /// Имя бота для отображения
    var botDisplayName: String {
        "@\(botUsername)"
    }

    /// Получить статистику трафика по токену
    func fetchStats(token: String, completion: @escaping (Result<VPNStats, Error>) -> Void) {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty,
              let url = URL(string: "\(serverURL)/stats/\(cleanToken)") else {
            completion(.failure(BotError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(BotError.invalidResponse)) }
                return
            }
            do {
                let stats = try JSONDecoder().decode(VPNStats.self, from: data)
                DispatchQueue.main.async { completion(.success(stats)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}

/// Статистика трафика VPN
struct VPNStats: Codable {
    let clientIp: String
    let received: Int64
    let sent: Int64
    let totalUsed: Int64
    let limit: Int64
    let remaining: Int64
    let remainingGb: Double
    let usedGb: Double

    enum CodingKeys: String, CodingKey {
        case clientIp = "client_ip"
        case received
        case sent
        case totalUsed = "total_used"
        case limit
        case remaining
        case remainingGb = "remaining_gb"
        case usedGb = "used_gb"
    }
}

/// Ошибки бота
enum BotError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidConfig

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .invalidResponse:
            return "Неверный ответ сервера"
        case .invalidConfig:
            return "Неверный формат конфига"
        }
    }
}
