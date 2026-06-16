import AppKit

struct MenuBarActions {
    let openSettings: @MainActor () -> Void
    let requestAccessibilityPermission: @MainActor () -> Void
    let startEventTap: @MainActor () -> Void
    let stopEventTap: @MainActor () -> Void
    let quit: @MainActor () -> Void
}

@MainActor
final class MenuBarController {
    private let appState: AppStateModel
    private let actions: MenuBarActions
    private let statusItem: NSStatusItem

    init(appState: AppStateModel, actions: MenuBarActions) {
        self.appState = appState
        self.actions = actions
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "rcmd"
            button.toolTip = "rcmd bootstrap"
        }

        refresh()
    }

    func refresh() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "rcmd bootstrap", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        let permissionTitle = appState.accessibilityTrusted
            ? "Accessibility: Granted"
            : "Accessibility: Missing"
        let permissionItem = NSMenuItem(title: permissionTitle, action: nil, keyEquivalent: "")
        permissionItem.isEnabled = false
        menu.addItem(permissionItem)

        let tapTitle = appState.eventTapRunning
            ? "Keyboard monitor: Running"
            : "Keyboard monitor: Stopped"
        let tapItem = NSMenuItem(title: tapTitle, action: nil, keyEquivalent: "")
        tapItem.isEnabled = false
        menu.addItem(tapItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(menuItem(title: "Settings...", action: #selector(openSettings)))

        if !appState.accessibilityTrusted {
            menu.addItem(menuItem(title: "Request Accessibility Permission", action: #selector(requestAccessibilityPermission)))
        }

        if appState.eventTapRunning {
            menu.addItem(menuItem(title: "Stop Keyboard Monitor", action: #selector(stopEventTap)))
        } else {
            menu.addItem(menuItem(title: "Start Keyboard Monitor", action: #selector(startEventTap)))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func openSettings() {
        actions.openSettings()
    }

    @objc private func requestAccessibilityPermission() {
        actions.requestAccessibilityPermission()
        refresh()
    }

    @objc private func startEventTap() {
        actions.startEventTap()
        refresh()
    }

    @objc private func stopEventTap() {
        actions.stopEventTap()
        refresh()
    }

    @objc private func quit() {
        actions.quit()
    }
}
