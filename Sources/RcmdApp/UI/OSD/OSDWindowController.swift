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
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel, panel.isVisible else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.06
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
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
        panel.contentViewController?.view.layoutSubtreeIfNeeded()

        let fittingSize = panel.contentViewController?.view.fittingSize ?? NSSize(width: 620, height: 260)
        let screenFrame = targetScreenFrame()
        let horizontalPadding: CGFloat = 32
        let verticalPadding: CGFloat = 28
        let maxWidth = max(360, screenFrame.width - horizontalPadding * 2)
        let maxHeight = max(120, min(640, screenFrame.height - verticalPadding * 2))
        let width = min(max(fittingSize.width, 420), min(maxWidth, 720))
        let height = min(max(fittingSize.height, 120), maxHeight)
        let originX = screenFrame.midX - width / 2
        let originY = screenFrame.maxY - height - verticalPadding

        panel.setFrame(
            NSRect(x: originX, y: originY, width: width, height: height),
            display: true
        )
    }

    private func targetScreenFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screen.visibleFrame
        }

        return NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 720, height: 480)
    }
}
