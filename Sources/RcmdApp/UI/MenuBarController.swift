import AppKit

struct MenuBarActions {
    let openSettings: @MainActor () -> Void
    let openQuickStart: @MainActor () -> Void
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.title = ""
            button.image = MenuBarIcon.make()
            button.imagePosition = .imageOnly
            button.toolTip = L10n.tr("app.name")
        }

        refresh()
    }

    func refresh() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: L10n.tr("menu.title"), action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        let permissionTitle = appState.accessibilityTrusted
            ? L10n.tr("menu.accessibilityGranted")
            : L10n.tr("menu.accessibilityMissing")
        let permissionItem = NSMenuItem(title: permissionTitle, action: nil, keyEquivalent: "")
        permissionItem.isEnabled = false
        menu.addItem(permissionItem)

        let tapTitle = appState.eventTapRunning
            ? L10n.tr("menu.keyboardMonitorRunning")
            : L10n.tr("menu.keyboardMonitorStopped")
        let tapItem = NSMenuItem(title: tapTitle, action: nil, keyEquivalent: "")
        tapItem.isEnabled = false
        menu.addItem(tapItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(menuItem(title: L10n.tr("menu.settings"), action: #selector(openSettings)))
        menu.addItem(menuItem(title: L10n.tr("menu.quickStart"), action: #selector(openQuickStart)))

        if !appState.accessibilityTrusted {
            menu.addItem(menuItem(title: L10n.tr("menu.requestAccessibility"), action: #selector(requestAccessibilityPermission)))
        }

        if appState.eventTapRunning {
            menu.addItem(menuItem(title: L10n.tr("menu.stopKeyboardMonitor"), action: #selector(stopEventTap)))
        } else {
            menu.addItem(menuItem(title: L10n.tr("menu.startKeyboardMonitor"), action: #selector(startEventTap)))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(title: L10n.tr("menu.quit"), action: #selector(quit), keyEquivalent: "q"))

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

    @objc private func openQuickStart() {
        actions.openQuickStart()
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
