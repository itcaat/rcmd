import Foundation

@MainActor
final class AppStateModel: ObservableObject {
    @Published var accessibilityTrusted = false
    @Published var eventTapRunning = false
    @Published var statusMessage = "Starting rcmd bootstrap."
    @Published private(set) var recentEvents: [String] = []
    @Published private(set) var assignments: [AppAssignment] = []
    @Published private(set) var appCatalog: [AppCatalogEntry] = []
    @Published private(set) var keyMappingMode: KeyMappingMode = .activeLayout
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginStatus = "Unknown"
    @Published private(set) var windows: [WindowInfo] = []
    @Published private(set) var lastShortcutMessage = "No shortcut handled yet."

    func refreshAccessibilityStatus() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }

    func refreshAssignments(_ assignments: [AppAssignment]) {
        self.assignments = assignments
    }

    func refreshAppCatalog(_ appCatalog: [AppCatalogEntry]) {
        self.appCatalog = appCatalog
    }

    func refreshKeyMappingMode(_ mode: KeyMappingMode) {
        keyMappingMode = mode
    }

    func refreshLaunchAtLogin(_ state: LaunchAtLoginState) {
        launchAtLoginEnabled = state.isEnabled
        launchAtLoginStatus = state.statusText
    }

    func refreshWindows(_ windows: [WindowInfo]) {
        self.windows = windows
    }

    func record(event: KeyEvent) {
        let line = event.displayDescription
        recentEvents.insert(line, at: 0)

        if recentEvents.count > 12 {
            recentEvents.removeLast(recentEvents.count - 12)
        }

        if event.isRightCommandKey || event.commandDown {
            AppLog.hotkeys.info("\(line, privacy: .public)")
        }
    }

    func record(shortcut: KeyShortcut, result: AppActivationResult) {
        lastShortcutMessage = "\(shortcut.displayDescription): \(result.displayMessage)"
        statusMessage = lastShortcutMessage

        AppLog.hotkeys.info("\(self.lastShortcutMessage, privacy: .public)")
    }

    func record(shortcut: KeyShortcut, assignmentResult: ManualAssignmentResult) {
        lastShortcutMessage = "\(shortcut.displayDescription): \(assignmentResult.displayMessage)"
        statusMessage = lastShortcutMessage

        AppLog.hotkeys.info("\(self.lastShortcutMessage, privacy: .public)")
    }

    func recordManualAssignmentResult(_ result: ManualAssignmentResult) {
        lastShortcutMessage = result.displayMessage
        statusMessage = lastShortcutMessage

        AppLog.app.info("\(self.lastShortcutMessage, privacy: .public)")
    }

    func recordManualAssignmentRemovalResult(_ result: ManualAssignmentRemovalResult) {
        lastShortcutMessage = result.displayMessage
        statusMessage = lastShortcutMessage

        AppLog.app.info("\(self.lastShortcutMessage, privacy: .public)")
    }

    func recordKeyMappingModeChange(_ mode: KeyMappingMode) {
        lastShortcutMessage = "Key mapping mode set to \(mode.displayName)."
        statusMessage = lastShortcutMessage

        AppLog.app.info("\(self.lastShortcutMessage, privacy: .public)")
    }

    func recordLaunchAtLoginResult(_ result: LaunchAtLoginResult) {
        lastShortcutMessage = result.displayMessage
        statusMessage = lastShortcutMessage

        AppLog.app.info("\(self.lastShortcutMessage, privacy: .public)")
    }
}
