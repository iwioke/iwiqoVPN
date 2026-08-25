import Foundation
import AppKit

/// Менеджер VPN-подключения.
/// Управляет WireGuard туннелем через wg-quick (без пароля через sudoers).
final class VPNManager: ObservableObject {

    static let shared = VPNManager()

    @Published var status: VPNStatus = .disconnected
    @Published var selectedServer: VPNServer?
    @Published var servers: [VPNServer] = []
    @Published var connectedTime: Date?
    @Published var dataReceived: Int64 = 0
    @Published var dataSent: Int64 = 0

    /// Callback при изменении статуса (для AppDelegate)
    var onStatusChange: ((VPNStatus) -> Void)?

    /// Имя туннеля WireGuard
    private let tunnelName = "iwiqo"
    private var timer: Timer?

    /// Путь к конфигу WireGuard
    private let configPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/wireguard/iwiqo.conf").path
    }()

    /// Пути к утилитам (Homebrew)
    private let wgQuickPath = "/opt/homebrew/bin/wg-quick"
    private let wgPath = "/opt/homebrew/bin/wg"
    private let sudoPath = "/usr/bin/sudo"

    /// VPN подсеть для проверки подключения (любой 10.8.0.x)
    private let vpnSubnet = "10.8.0."

    private init() {
        loadServers()
        checkStatus()
    }

    // MARK: - Servers

    /// Загрузка списка серверов
    private func loadServers() {
        servers = [
            VPNServer(
                name: "Германия — Франкфурт",
                location: "Frankfurt, DE",
                flag: "🇩🇪",
                configPath: nil
            ),
        ]
        selectedServer = servers.first
    }

    // MARK: - Status Check

    /// Проверить текущий статус туннеля при запуске
    private func checkStatus() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let connected = self.checkIfConnected()
            DispatchQueue.main.async {
                if connected {
                    self.status = .connected
                    self.connectedTime = Date()
                    self.startTimer()
                    self.onStatusChange?(self.status)
                }
            }
        }
    }

    /// Проверить, активен ли VPN через ifconfig
    private func checkIfConnected() -> Bool {
        let task = Process()
        task.launchPath = "/sbin/ifconfig"
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains(vpnSubnet)
        } catch {
            return false
        }
    }

    // MARK: - Connection

    /// Подключиться к VPN (без пароля — через sudoers правило)
    func connect() {
        guard FileManager.default.fileExists(atPath: configPath) else {
            status = .error("Конфиг не найден")
            onStatusChange?(status)
            return
        }

        status = .connecting
        onStatusChange?(status)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Сначала выключаем существующий туннель (если остался), потом подключаем
            let downTask = self.runSudo(command: self.wgQuickPath, args: ["down", self.configPath])
            _ = downTask

            // Подключаем
            let upTask = self.runSudo(command: self.wgQuickPath, args: ["up", self.configPath])
            let success = upTask.0 == 0
            let output = upTask.1

            DispatchQueue.main.async {
                if success {
                    // Проверяем подключение
                    self.verifyConnection()
                } else {
                    self.status = .error(self.cleanErrorMessage(output))
                    self.onStatusChange?(self.status)
                }
            }
        }
    }

    /// Отключиться от VPN
    func disconnect() {
        status = .disconnecting
        onStatusChange?(status)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let task = self.runSudo(command: self.wgQuickPath, args: ["down", self.configPath])
            let success = task.0 == 0

            DispatchQueue.main.async {
                // Даже если down вернул ошибку — проверяем реальный статус
                let stillConnected = self.checkIfConnected()
                if !stillConnected {
                    self.status = .disconnected
                    self.connectedTime = nil
                    self.stopTimer()
                    self.onStatusChange?(self.status)
                } else {
                    self.status = .error("Не удалось отключиться")
                    self.onStatusChange?(self.status)
                }
            }
        }
    }

    /// Переключить подключение
    func toggle() {
        if status == .connected || status == .connecting {
            disconnect()
        } else {
            connect()
        }
    }

    // MARK: - Sudo helper

    /// Запустить команду через sudo без пароля (sudoers правило)
    private func runSudo(command: String, args: [String]) -> (Int32, String) {
        let task = Process()
        task.launchPath = sudoPath
        task.arguments = ["-n", command] + args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (task.terminationStatus, output)
        } catch {
            return (-1, error.localizedDescription)
        }
    }

    // MARK: - Verification

    /// Проверить, что туннель действительно работает
    private func verifyConnection() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            // Небольшая задержка чтобы интерфейс поднялся
            Thread.sleep(forTimeInterval: 0.5)

            let connected = self.checkIfConnected()

            DispatchQueue.main.async {
                if connected {
                    self.status = .connected
                    self.connectedTime = Date()
                    self.startTimer()
                    self.onStatusChange?(self.status)
                } else {
                    self.status = .error("Туннель не поднялся")
                    self.onStatusChange?(self.status)
                }
            }
        }
    }

    // MARK: - Timer & Stats

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStats()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Обновить статистику — найти utun с IP 10.8.0.x и взять его трафик
    private func updateStats() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            // 1. Найти utun интерфейс с IP 10.8.0.x через ifconfig
            let ifconfigTask = Process()
            ifconfigTask.launchPath = "/sbin/ifconfig"
            ifconfigTask.arguments = ["-a"]
            let ifconfigPipe = Pipe()
            ifconfigTask.standardOutput = ifconfigPipe
            ifconfigTask.standardError = Pipe()
            do {
                try ifconfigTask.run()
                ifconfigTask.waitUntilExit()
                let ifconfigData = ifconfigPipe.fileHandleForReading.readDataToEndOfFile()
                let ifconfigOutput = String(data: ifconfigData, encoding: .utf8) ?? ""

                // Парсим ifconfig — ищем utun с inet 10.8.0.x
                var vpnInterface: String?
                let blocks = ifconfigOutput.components(separatedBy: "\n\n")
                for block in blocks {
                    if block.contains("utun") && block.contains("inet ") && block.contains(self.vpnSubnet) {
                        // Первая строка блока — имя интерфейса
                        if let firstLine = block.components(separatedBy: "\n").first {
                            vpnInterface = firstLine.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces)
                        }
                    }
                }

                guard let iface = vpnInterface else { return }

                // 2. Получить статистику через netstat -ib для найденного интерфейса
                let netstatTask = Process()
                netstatTask.launchPath = "/usr/sbin/netstat"
                netstatTask.arguments = ["-ib"]
                let netstatPipe = Pipe()
                netstatTask.standardOutput = netstatPipe
                netstatTask.standardError = Pipe()
                try netstatTask.run()
                netstatTask.waitUntilExit()
                let netstatData = netstatPipe.fileHandleForReading.readDataToEndOfFile()
                let netstatOutput = String(data: netstatData, encoding: .utf8) ?? ""

                var rx: Int64 = 0
                var tx: Int64 = 0
                let lines = netstatOutput.components(separatedBy: "\n")
                for line in lines {
                    // Ищем строку с Link и именем нашего интерфейса
                    if line.contains(iface) && line.contains("<Link#") {
                        let parts = line.components(separatedBy: " ").filter { !$0.isEmpty }
                        // Формат: Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll
                        if parts.count >= 10 {
                            rx = Int64(parts[6]) ?? 0
                            tx = Int64(parts[9]) ?? 0
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.dataReceived = rx
                    self.dataSent = tx
                }
            } catch {
                // Игнорируем
            }
        }
    }

    // MARK: - Helpers

    private func cleanErrorMessage(_ msg: String) -> String {
        var cleaned = msg.replacingOccurrences(of: "/opt/homebrew/bin/", with: "")
        if cleaned.count > 80 {
            cleaned = String(cleaned.prefix(80)) + "…"
        }
        return cleaned
    }

    // MARK: - Stats Formatted

    var connectionDuration: String {
        guard let start = connectedTime else { return "00:00:00" }
        let interval = Date().timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var dataReceivedFormatted: String {
        formatBytes(dataReceived)
    }

    var dataSentFormatted: String {
        formatBytes(dataSent)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
