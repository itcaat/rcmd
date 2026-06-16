import Foundation

@MainActor
final class AppStateModel: ObservableObject {
    @Published var accessibilityTrusted = false
    @Published var eventTapRunning = false
    @Published var statusMessage = "Starting rcmd bootstrap."
    @Published private(set) var recentEvents: [String] = []

    func refreshAccessibilityStatus() {
        accessibilityTrusted = AccessibilityPermission.isTrusted
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
}
