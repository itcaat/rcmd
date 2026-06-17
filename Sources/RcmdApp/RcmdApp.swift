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
    private var pendingOSDShowWorkItem: DispatchWorkItem?
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
        osdWindowController = OSDWindowController(
            appState: appState,
            actions: OSDActions(
                focusWindow: { [weak self] window in
                    self?.focus(window: window)
                },
                refreshWindows: { [weak self] in
                    self?.refreshWindows()
                },
                closeSearch: { [weak self] in
                    self?.closeWindowSearch()
                }
            )
        )
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

        eventTapController.onWindowSearchKeyAction = { [weak self] action in
            self?.handle(windowSearchKeyAction: action)
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
        cancelPendingOSDShow()
        osdWindowController?.hide()
        appState.eventTapRunning = false
        appState.statusMessage = "Keyboard monitor is stopped."
        menuBarController?.refresh()
    }

    private func handle(shortcut: KeyShortcut) {
        Task { @MainActor in
            cancelPendingOSDShow()

            if shortcut.kind == .openWindowSearch {
                toggleWindowSearch()
                return
            }

            eventTapController.isWindowSearchActive = false
            osdWindowController?.hideImmediately()

            switch shortcut.kind {
            case .activate:
                let result = await appRegistry.focusOrLaunchAssignedApp(for: shortcut.letter)
                appState.record(shortcut: shortcut, result: result)
            case .assign:
                let result = appRegistry.assignFrontmostApp(to: shortcut.letter)
                appState.record(shortcut: shortcut, assignmentResult: result)
            case .cycleWindow:
                let result = await windowRegistry.focusNextWindow()
                appState.record(shortcut: shortcut, windowFocusResult: result)
            case .openWindowSearch:
                break
            }

            refreshAssignments()
            refreshAppCatalog()
            refreshWindows()
            menuBarController?.refresh()
        }
    }

    private func handleRightCommandChanged(isHeld: Bool) {
        if isHeld {
            if appState.osdMode == .windowSearch {
                cancelPendingOSDShow()
                osdWindowController?.focusSearch()
            } else {
                scheduleAssignmentOSDShow()
            }
        } else if appState.osdMode == .windowSearch {
            cancelPendingOSDShow()
            osdWindowController?.focusSearch()
        } else {
            cancelPendingOSDShow()
            osdWindowController?.hide()
        }
    }

    private func scheduleAssignmentOSDShow() {
        cancelPendingOSDShow()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else {
                    return
                }

                self.refreshAssignments()
                self.refreshWindows()
                self.appState.showAssignmentOSD()
                self.osdWindowController?.show()
                self.pendingOSDShowWorkItem = nil
            }
        }

        pendingOSDShowWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func cancelPendingOSDShow() {
        pendingOSDShowWorkItem?.cancel()
        pendingOSDShowWorkItem = nil
    }

    private func toggleWindowSearch() {
        if appState.osdMode == .windowSearch {
            appState.showAssignmentOSD()
            eventTapController.isWindowSearchActive = false
            osdWindowController?.resignSearchIfNeeded()
        } else {
            appState.recordWindowSearchOpened()
            appState.showWindowSearchOSD()
            eventTapController.isWindowSearchActive = true
            updateWindowSearchSelection()
            osdWindowController?.activateSearchIfNeeded()
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
                updateWindowSearchSelection()
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

    func focus(window: WindowInfo) {
        Task { @MainActor in
            osdWindowController?.hideImmediately()
            appState.showAssignmentOSD()
            eventTapController.isWindowSearchActive = false
            let result = await windowRegistry.focus(window: window)
            appState.recordWindowSearchFocusResult(result)
            refreshWindows()
        }
    }

    func closeWindowSearch() {
        appState.showAssignmentOSD()
        eventTapController.isWindowSearchActive = false
        osdWindowController?.hideImmediately()
    }

    private func handle(windowSearchKeyAction action: WindowSearchKeyAction) {
        guard appState.osdMode == .windowSearch else {
            return
        }

        switch action {
        case .moveUp:
            moveWindowSearchSelection(by: -1)
        case .moveDown:
            moveWindowSearchSelection(by: 1)
        case .submit:
            focusSelectedSearchWindow()
        case .close:
            closeWindowSearch()
        case .deleteBackward:
            appState.deleteWindowSearchBackward()
            updateWindowSearchSelection()
        case .insertText(let text):
            appState.appendWindowSearchText(text)
            updateWindowSearchSelection()
        }
    }

    private var displayedWindowSearchWindows: [WindowInfo] {
        WindowSearchFilter.displayedWindows(appState.windows, query: appState.windowSearchQuery)
    }

    private func selectedSearchWindow() -> WindowInfo? {
        if let selectedWindowID = appState.selectedWindowID,
           let window = displayedWindowSearchWindows.first(where: { $0.id == selectedWindowID }) {
            return window
        }

        return displayedWindowSearchWindows.first
    }

    private func updateWindowSearchSelection() {
        guard appState.osdMode == .windowSearch else {
            return
        }

        if let selectedWindowID = appState.selectedWindowID,
           displayedWindowSearchWindows.contains(where: { $0.id == selectedWindowID }) {
            return
        }

        appState.selectWindow(id: displayedWindowSearchWindows.first?.id)
    }

    private func moveWindowSearchSelection(by offset: Int) {
        guard !displayedWindowSearchWindows.isEmpty else {
            appState.selectWindow(id: nil)
            return
        }

        let currentIndex = appState.selectedWindowID.flatMap { selectedWindowID in
            displayedWindowSearchWindows.firstIndex(where: { $0.id == selectedWindowID })
        } ?? displayedWindowSearchWindows.startIndex

        let nextIndex = max(
            displayedWindowSearchWindows.startIndex,
            min(displayedWindowSearchWindows.index(before: displayedWindowSearchWindows.endIndex), currentIndex + offset)
        )
        appState.selectWindow(id: displayedWindowSearchWindows[nextIndex].id)
    }

    private func focusSelectedSearchWindow() {
        guard let window = selectedSearchWindow() else {
            return
        }

        focus(window: window)
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
