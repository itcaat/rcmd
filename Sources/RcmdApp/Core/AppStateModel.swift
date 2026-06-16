import Foundation

@MainActor
final class AppStateModel: ObservableObject {
    @Published var accessibilityTrusted = false
    @Published var eventTapRunning = false
    @Published var statusMessage = "Starting rcmd bootstrap."
    @Published private(set) var recentEvents: [String] = []
    @Published private(set) var assignments: [AppAssignment] = []
    @Published private(set) var lastShortcutMessage = "No shortcut handled yet."

    func refreshAccessibilityStatus() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }

    func refreshAssignments(_ assignments: [AppAssignment]) {
        self.assignments = assignments
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
}
