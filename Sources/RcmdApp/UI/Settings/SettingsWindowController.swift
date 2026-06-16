import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let appState: AppStateModel
    private var window: NSWindow?

    init(appState: AppStateModel) {
        self.appState = appState
    }

    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: SettingsView(appState: appState))
            let newWindow = NSWindow(contentViewController: hostingController)
            newWindow.title = "rcmd Settings"
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            window = newWindow
        }

        window?.makeKeyAndOrderFront(nil)
    }
}
