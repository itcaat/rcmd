import AppKit
import Foundation

@MainActor
final class RcmdApp: NSObject, NSApplicationDelegate {
    private let appState = AppStateModel()
    private let assignmentStore: AssignmentStore
    private let appRegistry: AppRegistry
    private let windowRegistry = WindowRegistry()
    private let launchAtLoginController = LaunchAtLoginController()
    private let eventTapController = EventTapController()
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var osdWindowController: OSDWindowController?
    private var permissionTimer: Timer?
    private var isWindowRefreshInFlight = false
    private var needsWindowRefresh = false
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

        settingsWindowController = SettingsWindowController(
            appState: appState,
            actions: SettingsActions(
                assignApp: { [weak self] bundleIdentifier, letter in
                    self?.assign(bundleIdentifier: bundleIdentifier, to: letter)
                },
                removeManualAssignment: { [weak self] letter in
                    self?.removeManualAssignment(for: letter)
                },
                setKeyMappingMode: { [weak self] mode in
                    self?.setKeyMappingMode(mode)
                },
                setLaunchAtLogin: { [weak self] enabled in
                    self?.setLaunchAtLoginEnabled(enabled)
                }
            )
        )
        osdWindowController = OSDWindowController(appState: appState)
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

        eventTapController.onRightCommandChanged = { [weak self] isHeld in
            self?.handleRightCommandChanged(isHeld: isHeld)
        }

        refreshAccessibilityAndStartMonitorIfReady()
        refreshKeyMappingMode()
        refreshLaunchAtLogin()
        refreshAssignments()
        refreshAppCatalog()
        refreshWindows()
        installWorkspaceObservers()
        menuBarController?.refresh()

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAccessibilityAndStartMonitorIfReady()
                self?.refreshWindows()
            }
        }

        if !appState.accessibilityTrusted {
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

    private func refreshAccessibilityAndStartMonitorIfReady() {
        let wasTrusted = appState.accessibilityTrusted
        appState.refreshAccessibilityStatus()

        if appState.accessibilityTrusted, !eventTapController.isRunning {
            startEventTap()
        } else if !wasTrusted || wasTrusted != appState.accessibilityTrusted {
            menuBarController?.refresh()
        }
    }

    private func startEventTap() {
        if eventTapController.isRunning {
            appState.eventTapRunning = true
            menuBarController?.refresh()
            return
        }

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
        osdWindowController?.hide()
        appState.eventTapRunning = false
        appState.statusMessage = "Keyboard monitor is stopped."
        menuBarController?.refresh()
    }

    private func handle(shortcut: KeyShortcut) {
        Task { @MainActor in
            refreshAssignments()
            refreshWindows()

            switch shortcut.kind {
            case .activate:
                let result = await appRegistry.focusOrLaunchAssignedApp(for: shortcut.letter)
                appState.record(shortcut: shortcut, result: result)
            case .assign:
                let result = appRegistry.assignFrontmostApp(to: shortcut.letter)
                appState.record(shortcut: shortcut, assignmentResult: result)
            }

            refreshAssignments()
            refreshAppCatalog()
            refreshWindows()
            menuBarController?.refresh()
            osdWindowController?.hide()
        }
    }

    private func handleRightCommandChanged(isHeld: Bool) {
        if isHeld {
            refreshAssignments()
            refreshWindows()
            osdWindowController?.show()
        } else {
            osdWindowController?.hide()
        }
    }

    private func refreshAssignments() {
        appState.refreshAssignments(appRegistry.currentAssignments())
    }

    private func refreshAppCatalog() {
        appState.refreshAppCatalog(appRegistry.appCatalog())
    }

    private func refreshWindows() {
        guard !isWindowRefreshInFlight else {
            needsWindowRefresh = true
            return
        }

        isWindowRefreshInFlight = true

        Task { @MainActor in
            repeat {
                needsWindowRefresh = false
                let windows = await windowRegistry.currentWindows()
                appState.refreshWindows(windows)
            } while needsWindowRefresh

            isWindowRefreshInFlight = false
        }
    }

    private func refreshKeyMappingMode() {
        eventTapController.keyMappingMode = assignmentStore.keyMappingMode
        appState.refreshKeyMappingMode(assignmentStore.keyMappingMode)
    }

    private func refreshLaunchAtLogin() {
        appState.refreshLaunchAtLogin(launchAtLoginController.currentState())
    }

    func assign(bundleIdentifier: String, to letter: Character) {
        let result = appRegistry.assign(bundleIdentifier: bundleIdentifier, to: letter)
        appState.recordManualAssignmentResult(result)
        refreshAssignments()
        refreshAppCatalog()
        menuBarController?.refresh()
    }

    func removeManualAssignment(for letter: Character) {
        let result = appRegistry.removeManualAssignment(for: letter)
        appState.recordManualAssignmentRemovalResult(result)
        refreshAssignments()
        refreshAppCatalog()
        menuBarController?.refresh()
    }

    func setKeyMappingMode(_ mode: KeyMappingMode) {
        assignmentStore.setKeyMappingMode(mode)
        refreshKeyMappingMode()
        appState.recordKeyMappingModeChange(mode)
        menuBarController?.refresh()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        let result = launchAtLoginController.setEnabled(enabled)
        refreshLaunchAtLogin()
        appState.recordLaunchAtLoginResult(result)
        menuBarController?.refresh()
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
                    self?.refreshAppCatalog()
                    self?.refreshWindows()
                }
            }
        }
    }
}
