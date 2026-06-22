import AppKit
import SwiftUI

struct QuickStartActions {
    let requestAccessibilityPermission: @MainActor () -> Void
    let openSettings: @MainActor () -> Void
    let dismiss: @MainActor () -> Void
}

@MainActor
final class QuickStartWindowController {
    private let appState: AppStateModel
    private let actions: QuickStartActions
    private var window: NSWindow?

    init(appState: AppStateModel, actions: QuickStartActions) {
        self.appState = appState
        self.actions = actions
    }

    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: QuickStartView(appState: appState, actions: actions))
            let newWindow = NSWindow(contentViewController: hostingController)
            newWindow.title = L10n.tr("quickStart.windowTitle")
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.setContentSize(NSSize(width: 640, height: 440))
            newWindow.minSize = NSSize(width: 600, height: 400)
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            window = newWindow
        }

        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }
}
