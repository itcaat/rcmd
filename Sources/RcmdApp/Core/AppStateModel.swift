import Foundation

enum OSDMode: Sendable, Equatable {
    case assignments
    case windowSearch
}

@MainActor
final class AppStateModel: ObservableObject {
    @Published var accessibilityTrusted = false
    @Published var eventTapRunning = false
    @Published var statusMessage = L10n.tr("status.starting")
    @Published private(set) var recentEvents: [String] = []
    @Published private(set) var assignments: [AppAssignment] = []
    @Published private(set) var appCatalog: [AppCatalogEntry] = []
    @Published private(set) var keyMappingMode: KeyMappingMode = .activeLayout
    @Published private(set) var minimizeActiveWindowOnRepeatedShortcut = false
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginStatus = L10n.tr("state.unknown")
    @Published private(set) var windows: [WindowInfo] = []
    @Published private(set) var osdMode: OSDMode = .assignments
    @Published private(set) var windowSearchQuery = ""
    @Published private(set) var selectedWindowID: WindowInfo.ID?
    @Published private(set) var lastShortcutMessage = L10n.tr("status.noShortcut")

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

    func refreshMinimizeActiveWindowOnRepeatedShortcut(_ enabled: Bool) {
        minimizeActiveWindowOnRepeatedShortcut = enabled
    }

    func refreshLaunchAtLogin(_ state: LaunchAtLoginState) {
        launchAtLoginEnabled = state.isEnabled
        launchAtLoginStatus = state.statusText
    }

    func refreshWindows(_ windows: [WindowInfo]) {
        self.windows = windows
    }

    func showAssignmentOSD() {
        osdMode = .assignments
        windowSearchQuery = ""
        selectedWindowID = nil
    }

    func showWindowSearchOSD() {
        osdMode = .windowSearch
        windowSearchQuery = ""
        selectedWindowID = nil
    }

    func setWindowSearchQuery(_ query: String) {
        windowSearchQuery = query
    }

    func appendWindowSearchText(_ text: String) {
        windowSearchQuery += text
    }

    func deleteWindowSearchBackward() {
        guard !windowSearchQuery.isEmpty else {
            return
        }

        windowSearchQuery.removeLast()
    }

    func selectWindow(id: WindowInfo.ID?) {
        selectedWindowID = id
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

    func record(shortcut: KeyShortcut, windowFocusResult: WindowFocusResult) {
        lastShortcutMessage = "\(shortcut.displayDescription): \(windowFocusResult.displayMessage)"
        statusMessage = lastShortcutMessage

        AppLog.hotkeys.info("\(self.lastShortcutMessage, privacy: .public)")
    }

    func recordWindowSearchOpened() {
        lastShortcutMessage = L10n.tr("status.windowSearchOpened")
        statusMessage = lastShortcutMessage

        AppLog.hotkeys.info("\(self.lastShortcutMessage, privacy: .public)")
    }

    func recordWindowSearchFocusResult(_ result: WindowFocusResult) {
        lastShortcutMessage = L10n.tr("status.windowSearchResult", result.displayMessage)
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
        lastShortcutMessage = L10n.tr("status.keyMappingChanged", mode.displayName)
        statusMessage = lastShortcutMessage

        AppLog.app.info("\(self.lastShortcutMessage, privacy: .public)")
    }

    func recordMinimizeActiveWindowOnRepeatedShortcutChange(_ enabled: Bool) {
        lastShortcutMessage = enabled
            ? L10n.tr("status.repeatedShortcutMinimizeEnabled")
            : L10n.tr("status.repeatedShortcutMinimizeDisabled")
        statusMessage = lastShortcutMessage

        AppLog.app.info("\(self.lastShortcutMessage, privacy: .public)")
    }

    func recordLaunchAtLoginResult(_ result: LaunchAtLoginResult) {
        lastShortcutMessage = result.displayMessage
        statusMessage = lastShortcutMessage

        AppLog.app.info("\(self.lastShortcutMessage, privacy: .public)")
    }
}
