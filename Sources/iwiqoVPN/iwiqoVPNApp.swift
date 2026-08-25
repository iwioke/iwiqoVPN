import SwiftUI
import AppKit

@main
struct iwiqoVPNApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Запрещаем macOS автоматически завершать menu bar приложение
        ProcessInfo.processInfo.disableAutomaticTermination("iwiqo-running")
        ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "iwiqo VPN работает в menu bar"
        )
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
