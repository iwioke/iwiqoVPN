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
    private var healthTimer: Timer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var shouldReconnect = false
    private var tunnelOperationInProgress = false
    private var healthCheckInProgress = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3

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
            let interface = self.recentHandshakeInterface()
            DispatchQueue.main.async {
                guard interface != nil else { return }
                self.status = .connected
                self.connectedTime = Date()
                self.shouldReconnect = true
                self.reconnectAttempts = 0
                self.startTimer()
                self.onStatusChange?(self.status)
            }
        }
    }

    /// Проверить, активен ли VPN через ifconfig
    private func checkIfConnected() -> Bool {
        currentTunnelInterface() != nil
    }

    private func currentTunnelInterface() -> String? {
        let result = runSudo(command: wgPath, args: ["show", "interfaces"])
        guard result.0 == 0 else { return nil }

        let interfaces = result.1.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !interfaces.isEmpty else { return nil }

        if interfaces.contains(tunnelName) {
            return tunnelName
        }

        let addresses = configuredTunnelAddresses()
        guard !addresses.isEmpty else { return nil }

        for interface in interfaces {
            let output = runCommand(command: "/sbin/ifconfig", args: [interface])
            if output.0 == 0 && addresses.contains(where: { output.1.contains($0) }) {
                return interface
            }
        }

        return nil
    }

    private func recentHandshakeInterface(maximumAge: TimeInterval = 90) -> String? {
        guard let interface = currentTunnelInterface() else { return nil }
        let result = runSudo(command: wgPath, args: ["show", interface, "latest-handshakes"])
        guard result.0 == 0 else { return nil }

        let timestamps = result.1
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { Int64($0) }

        guard let latest = timestamps.max(), latest > 0 else { return nil }
        let age = Date().timeIntervalSince1970 - TimeInterval(latest)
        return age >= 0 && age <= maximumAge ? interface : nil
    }

    private func configuredTunnelAddresses() -> [String] {
        guard let config = try? String(contentsOfFile: configPath, encoding: .utf8) else { return [] }

        var isInterfaceSection = false
        var addresses: [String] = []

        for line in config.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                isInterfaceSection = trimmed.caseInsensitiveCompare("[Interface]") == .orderedSame
                continue
            }

            guard isInterfaceSection, let keyValue = configKeyValue(from: trimmed), keyValue.0 == "address" else {
                continue
            }

            addresses.append(contentsOf: keyValue.1
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .map { String($0.split(separator: "/", maxSplits: 1).first ?? "") }
                .filter { !$0.isEmpty })
        }

        return addresses
    }

    private func configKeyValue(from line: String) -> (String, String)? {
        let uncommented = line.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
        let parts = uncommented.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (
            parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func ensurePersistentKeepalive() throws {
        let config = try String(contentsOfFile: configPath, encoding: .utf8)
        let updatedConfig = addingPersistentKeepalive(to: config)
        guard updatedConfig != config else { return }

        try updatedConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configPath)
    }

    private func addingPersistentKeepalive(to config: String) -> String {
        let hadTrailingNewline = config.hasSuffix("\n")
        var lines = config.components(separatedBy: .newlines)
        if hadTrailingNewline {
            lines.removeLast()
        }

        var updatedLines: [String] = []
        var isPeerSection = false
        var peerHasKeepalive = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                if isPeerSection && !peerHasKeepalive {
                    updatedLines.append("PersistentKeepalive = 25")
                }
                isPeerSection = trimmed.caseInsensitiveCompare("[Peer]") == .orderedSame
                peerHasKeepalive = false
            } else if isPeerSection, let keyValue = configKeyValue(from: trimmed), keyValue.0 == "persistentkeepalive" {
                peerHasKeepalive = true
            }
            updatedLines.append(line)
        }

        if isPeerSection && !peerHasKeepalive {
            updatedLines.append("PersistentKeepalive = 25")
        }

        var result = updatedLines.joined(separator: "\n")
        if hadTrailingNewline {
            result.append("\n")
        }
        return result
    }

    private func persistentKeepaliveIsEnabled() -> Bool {
        guard let config = try? String(contentsOfFile: configPath, encoding: .utf8) else { return false }

        var isPeerSection = false
        for line in config.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                isPeerSection = trimmed.caseInsensitiveCompare("[Peer]") == .orderedSame
                continue
            }

            guard isPeerSection, let keyValue = configKeyValue(from: trimmed), keyValue.0 == "persistentkeepalive" else {
                continue
            }

            return (Int(keyValue.1) ?? 0) > 0
        }

        return false
    }

    // MARK: - Connection

    /// Подключиться к VPN (без пароля — через sudoers правило)
    func connect() {
        guard !status.isTransitioning, !tunnelOperationInProgress else { return }
        shouldReconnect = true
        reconnectAttempts = 0
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        beginConnection(reconnecting: false)
    }

    private func beginConnection(reconnecting: Bool) {
        guard !tunnelOperationInProgress else { return }
        guard FileManager.default.fileExists(atPath: configPath) else {
            connectionFailed("Конфиг не найден", reconnecting: reconnecting)
            return
        }

        tunnelOperationInProgress = true
        reconnectWorkItem = nil
        status = .connecting
        onStatusChange?(status)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                try self.ensurePersistentKeepalive()
            } catch {
                DispatchQueue.main.async {
                    self.connectionFailed("Не удалось обновить конфиг", reconnecting: reconnecting)
                }
                return
            }

            // Сначала выключаем существующий туннель (если остался), потом подключаем
            let downTask = self.runSudo(command: self.wgQuickPath, args: ["down", self.configPath])
            _ = downTask

            // Подключаем
            let upTask = self.runSudo(command: self.wgQuickPath, args: ["up", self.configPath])
            let success = upTask.0 == 0
            let output = upTask.1

            DispatchQueue.main.async {
                if success {
                    self.verifyConnection(reconnecting: reconnecting)
                } else {
                    self.connectionFailed(self.cleanErrorMessage(output), reconnecting: reconnecting)
                }
            }
        }
    }

    /// Отключиться от VPN
    func disconnect() {
        guard !status.isTransitioning, !tunnelOperationInProgress else { return }
        shouldReconnect = false
        reconnectAttempts = 0
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        tunnelOperationInProgress = true
        status = .disconnecting
        onStatusChange?(status)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let task = self.runSudo(command: self.wgQuickPath, args: ["down", self.configPath])
            let success = task.0 == 0
            _ = success

            DispatchQueue.main.async {
                self.tunnelOperationInProgress = false
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
        guard !status.isTransitioning, !tunnelOperationInProgress else { return }
        if status == .connected {
            disconnect()
        } else {
            connect()
        }
    }

    func handleSystemWake() {
        guard status == .connected else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.monitorTunnelHealth()
        }
    }

    private func connectionFailed(_ message: String, reconnecting: Bool) {
        tunnelOperationInProgress = false
        if reconnecting {
            scheduleReconnect()
            return
        }

        shouldReconnect = false
        status = .error(message)
        onStatusChange?(status)
    }

    private func scheduleReconnect() {
        guard shouldReconnect else { return }
        guard reconnectAttempts < maxReconnectAttempts else {
            shouldReconnect = false
            status = .error("Туннель не восстановлен")
            onStatusChange?(status)
            return
        }

        reconnectAttempts += 1
        status = .connecting
        onStatusChange?(status)

        let delay = min(pow(2, Double(reconnectAttempts - 1)), 30)
        let workItem = DispatchWorkItem { [weak self] in
            self?.beginConnection(reconnecting: true)
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
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

    private func runCommand(command: String, args: [String]) -> (Int32, String) {
        let task = Process()
        task.launchPath = command
        task.arguments = args

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
    private func verifyConnection(reconnecting: Bool) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            // Небольшая задержка чтобы интерфейс поднялся
            var interface: String?
            for _ in 0..<10 {
                if let activeInterface = self.recentHandshakeInterface() {
                    interface = activeInterface
                    break
                }
                Thread.sleep(forTimeInterval: 1)
            }

            DispatchQueue.main.async {
                if interface != nil {
                    self.status = .connected
                    self.connectedTime = Date()
                    self.reconnectAttempts = 0
                    self.tunnelOperationInProgress = false
                    self.startTimer()
                    self.onStatusChange?(self.status)
                } else {
                    self.connectionFailed("Сервер не подтвердил соединение", reconnecting: reconnecting)
                }
            }
        }
    }

    private func monitorTunnelHealth() {
        guard status == .connected,
              shouldReconnect,
              persistentKeepaliveIsEnabled(),
              !healthCheckInProgress,
              !tunnelOperationInProgress else {
            return
        }

        healthCheckInProgress = true
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let isHealthy = self.recentHandshakeInterface() != nil
            DispatchQueue.main.async {
                self.healthCheckInProgress = false
                if isHealthy {
                    self.reconnectAttempts = 0
                } else {
                    self.scheduleReconnect()
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
        healthTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.monitorTunnelHealth()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        healthTimer?.invalidate()
        healthTimer = nil
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
                let tunnelAddresses = self.configuredTunnelAddresses()
                guard !tunnelAddresses.isEmpty else { return }

                // Парсим ifconfig — ищем utun с inet 10.8.0.x
                var vpnInterface: String?
                let blocks = ifconfigOutput.components(separatedBy: "\n\n")
                for block in blocks {
                    if block.contains("utun") && block.contains("inet ") && tunnelAddresses.contains(where: { block.contains($0) }) {
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
