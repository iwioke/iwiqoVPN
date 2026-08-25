<div align="center">

# iwiqoVPN

**Минималистичный VPN-клиент для macOS, живущий в строке меню**

Построен на WireGuard · SwiftUI · macOS 13+

![Platform](https://img.shields.io/badge/platform-macOS-000000?style=flat-square&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white)
![WireGuard](https://img.shields.io/badge/WireGuard-powered-88171A?style=flat-square&logo=wireguard&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-1.0,0.2,0.6?style=flat-square)

</div>

---

## О проекте

iwiqoVPN — это лёгкое menu-bar приложение для macOS, которое управляет WireGuard-туннелем в один клик. Никаких тяжёлых окон — только иконка в строке меню и аккуратный popover с кнопкой подключения, статистикой трафика и выбором сервера.

### Возможности

- **One-click подключение** — большая круглая кнопка с анимацией статуса
- **Live-статистика** — время сессии, отправлено/получено, остаток трафика
- **Выбор сервера** — раскрывающийся список с флагами
- **Две темы** — тёмная (розово-чёрная) и светлая (розово-белая)
- **Автозапуск с Mac** — через `SMAppService`
- **Конфиг через Telegram-бота** — получение WireGuard-конфига по токену
- **Menu bar иконка** — меняет цвет в зависимости от статуса (розовая = подключено)

## Скриншоты

> Добавьте скриншоты в `Resources/` и ссылайтесь на них здесь.

## Требования

| Компонент | Версия |
|-----------|--------|
| macOS | 13.0+ (Ventura) |
| Swift | 5.9 |
| Xcode | 15+ |
| WireGuard | `brew install wireguard-tools` |
| XcodeGen | `brew install xcodegen` (для генерации `.xcodeproj`) |

## Установка

### 1. Установить WireGuard

```bash
brew install wireguard-tools
```

### 2. Настроить sudoers (запуск `wg-quick` без пароля)

```bash
echo "ALL ALL=(root) NOPASSWD: /opt/homebrew/bin/wg-quick" | sudo tee /etc/sudoers.d/iwiqo-vpn
echo "ALL ALL=(root) NOPASSWD: /opt/homebrew/bin/wg" | sudo tee -a /etc/sudoers.d/iwiqo-vpn
```

### 3. Сгенерировать Xcode-проект

```bash
xcodegen generate
```

### 4. Открыть и собрать

```bash
open iwiqoVPN.xcodeproj
```

В Xcode: **Cmd + R** для запуска.

## Использование

1. Запустите приложение — иконка щита появится в строке меню
2. Нажмите на иконку → откроется popover
3. Перейдите в раздел **«Конфиг»** → получите токен в Telegram-боте `@iwiqo_vpn_bot`
4. Вставьте токен → конфиг скачается автоматически
5. Нажмите большую кнопку для подключения

## Архитектура

```
iwiqoVPN/
├── project.yml                  # XcodeGen-спецификация
├── Sources/iwiqoVPN/
│   ├── iwiqoVPNApp.swift        # Точка входа SwiftUI
│   ├── AppDelegate.swift        # Menu bar, popover, иконка статуса
│   ├── Models/
│   │   └── VPNModels.swift      # VPNStatus, VPNServer
│   ├── Services/
│   │   ├── VPNManager.swift     # Управление wg-quick туннелем
│   │   ├── BotService.swift     # Telegram-бот: конфиг + статистика
│   │   ├── ThemeManager.swift   # Тёмная/светлая тема
│   │   └── SettingsManager.swift# Автозапуск, настройки
│   └── Views/
│       ├── MainView.swift       # Главный popover: кнопка, статистика, серверы
│       ├── SetupView.swift      # Экран получения конфига
│       └── SettingsView.swift   # Настройки и тема
└── Resources/
```

### Как это работает

- **VPNManager** вызывает `sudo wg-quick up/down` (без пароля через sudoers)
- Статус проверяется через `ifconfig` (поиск интерфейса с IP `10.8.0.x`)
- Трафик читается из `netstat -ib` для найденного `utun`-интерфейса
- **BotService** скачивает WireGuard-конфиг по токену с backend-сервера
- Иконка в menu bar красится программно через `NSImage.lockFocus`

## Лицензия

MIT © 2026 iwiqo
