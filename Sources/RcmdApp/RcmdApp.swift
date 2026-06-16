import AppKit
import Foundation

@MainActor
final class RcmdApp: NSObject, NSApplicationDelegate {
    private let appState = AppStateModel()
    private let assignmentStore: AssignmentStore
    private let appRegistry: AppRegistry
    private let eventTapController = EventTapController()
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var permissionTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    override init() {
        let assignmentStore = AssignmentStore()
        self.assignmentStore = assignmentStore
        appRegistry = AppRegistry(assignmentStore: assignmentStore)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppLog.app.info("rcmd app did finish launching")

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

        eventTapController.onShortcut = { [weak self] shortcut in
            self?.handle(shortcut: shortcut)
        }

        appState.refreshAccessibilityStatus()
        refreshAssignments()
        installWorkspaceObservers()
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
        workspaceObservers.forEach { observer in
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
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

    private func handle(shortcut: KeyShortcut) {
        Task { @MainActor in
            refreshAssignments()

            switch shortcut.kind {
            case .activate:
                let result = await appRegistry.focusOrLaunchAssignedApp(for: shortcut.letter)
                appState.record(shortcut: shortcut, result: result)
            case .assign:
                let result = appRegistry.assignFrontmostApp(to: shortcut.letter)
                appState.record(shortcut: shortcut, assignmentResult: result)
            }

            refreshAssignments()
            menuBarController?.refresh()
        }
    }

    private func refreshAssignments() {
        appState.refreshAssignments(appRegistry.currentAssignments())
    }

    private func installWorkspaceObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let notifications: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification
        ]

        workspaceObservers = notifications.map { notificationName in
            notificationCenter.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAssignments()
                }
            }
        }
    }
}
