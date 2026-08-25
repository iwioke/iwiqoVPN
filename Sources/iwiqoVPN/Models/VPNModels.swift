import Foundation

/// Статус VPN подключения
enum VPNStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(String)

    var label: String {
        switch self {
        case .disconnected: return "Отключён"
        case .connecting: return "Подключение…"
        case .connected: return "Подключён"
        case .disconnecting: return "Отключение…"
        case .error(let msg): return "Ошибка: \(msg)"
        }
    }

    var isConnected: Bool { self == .connected }
    var isTransitioning: Bool { self == .connecting || self == .disconnecting }
}

/// Модель сервера
struct VPNServer: Identifiable, Codable {
    let id: UUID
    var name: String
    var location: String
    var flag: String
    var configPath: String?

    init(id: UUID = UUID(), name: String, location: String, flag: String, configPath: String? = nil) {
        self.id = id
        self.name = name
        self.location = location
        self.flag = flag
        self.configPath = configPath
    }
}
