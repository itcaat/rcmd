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

    func record(shortcut: KeyShortcut, focused assignment: AppAssignment?) {
        if let assignment {
            lastShortcutMessage = "\(shortcut.displayDescription) focused \(assignment.appName)."
            statusMessage = lastShortcutMessage
        } else {
            lastShortcutMessage = "\(shortcut.displayDescription) has no running app assignment."
            statusMessage = lastShortcutMessage
        }

        AppLog.hotkeys.info("\(self.lastShortcutMessage, privacy: .public)")
    }
}
