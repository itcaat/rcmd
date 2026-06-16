import AppKit
import Foundation

@main
@MainActor
final class RcmdApp: NSObject, NSApplicationDelegate {
    private let appState = AppStateModel()
    private let eventTapController = EventTapController()
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        settingsWindowController = SettingsWindowController(appState: appState)
        menuBarController = MenuBarController(
            appState: appState,
            actions: MenuBarActions(
                openSettings: { [weak self] in self?.showSettings() },
                requestAccessibilityPermission: {
                    AccessibilityPermission.request()
                },
                startEventTap: { [weak self] in self?.startEventTap() },
                stopEventTap: { [weak self] in self?.stopEventTap() },
                quit: {
                    NSApp.terminate(nil)
                }
            )
        )

        eventTapController.onEvent = { [weak self] event in
            self?.appState.record(event: event)
        }

        appState.refreshAccessibilityStatus()
        menuBarController?.refresh()

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.appState.refreshAccessibilityStatus()
                self?.menuBarController?.refresh()
            }
        }

        if appState.accessibilityTrusted {
            startEventTap()
        } else {
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopEventTap()
        permissionTimer?.invalidate()
    }

    private func showSettings() {
        settingsWindowController?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func startEventTap() {
        do {
            try eventTapController.start()
            appState.eventTapRunning = true
            appState.statusMessage = "Keyboard monitor is running."
            menuBarController?.refresh()
        } catch {
            appState.eventTapRunning = false
            appState.statusMessage = "Keyboard monitor failed: \(error.localizedDescription)"
            AppLog.hotkeys.error("Failed to start event tap: \(error.localizedDescription, privacy: .public)")
            showSettings()
            menuBarController?.refresh()
        }
    }

    private func stopEventTap() {
        eventTapController.stop()
        appState.eventTapRunning = false
        appState.statusMessage = "Keyboard monitor is stopped."
        menuBarController?.refresh()
    }
}
