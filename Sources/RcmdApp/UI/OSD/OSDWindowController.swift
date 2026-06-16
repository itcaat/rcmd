import AppKit
import SwiftUI

@MainActor
final class OSDWindowController {
    private let appState: AppStateModel
    private var panel: NSPanel?

    init(appState: AppStateModel) {
        self.appState = appState
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let hostingController = NSHostingController(rootView: OSDView(appState: appState))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        return panel
    }

    private func position(_ panel: NSPanel) {
        let fittingSize = panel.contentViewController?.view.fittingSize ?? NSSize(width: 560, height: 260)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let width = min(max(fittingSize.width, 360), min(screenFrame.width - 32, 640))
        let height = min(max(fittingSize.height, 120), min(screenFrame.height - 32, 420))
        let originX = screenFrame.midX - width / 2
        let originY = screenFrame.maxY - height - 28

        panel.setFrame(
            NSRect(x: originX, y: originY, width: width, height: height),
            display: true
        )
    }
}
