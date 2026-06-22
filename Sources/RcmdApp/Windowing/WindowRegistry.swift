import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

final class WindowRegistry {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    @MainActor
    func currentWindows() async -> [WindowInfo] {
        guard AccessibilityPermission.isTrusted else {
            return []
        }

        let appSnapshots = workspace.runningApplications.compactMap(WindowAppSnapshot.init(app:))

        return await Task.detached(priority: .utility) {
            WindowRegistry.readWindows(for: appSnapshots)
        }.value
    }

    @MainActor
    func focusNextWindow() async -> WindowFocusResult {
        guard AccessibilityPermission.isTrusted else {
            return .failed(L10n.tr("error.accessibilityPermissionRequired"))
        }

        let appSnapshots = workspace.runningApplications.compactMap(WindowAppSnapshot.init(app:))
        let frontmostProcessIdentifier = workspace.frontmostApplication?.processIdentifier
        let result = await Task.detached(priority: .userInitiated) {
            WindowRegistry.focusNextWindow(
                in: appSnapshots,
                frontmostProcessIdentifier: frontmostProcessIdentifier
            )
        }.value

        if case .focused(let window) = result,
           let app = workspace.runningApplications.first(where: { $0.processIdentifier == window.processIdentifier }) {
            app.unhide()
            app.activate(options: [.activateAllWindows])
        }

        return result
    }

    @MainActor
    func focus(window: WindowInfo) async -> WindowFocusResult {
        guard AccessibilityPermission.isTrusted else {
            return .failed(L10n.tr("error.accessibilityPermissionRequired"))
        }

        let appSnapshots = workspace.runningApplications.compactMap(WindowAppSnapshot.init(app:))
        let result = await Task.detached(priority: .userInitiated) {
            WindowRegistry.focus(window: window, in: appSnapshots)
        }.value

        if case .focused(let focusedWindow) = result,
           let app = workspace.runningApplications.first(where: { $0.processIdentifier == focusedWindow.processIdentifier }) {
            app.unhide()
            app.activate(options: [.activateAllWindows])
        }

        return result
    }

    private static func readWindows(for apps: [WindowAppSnapshot]) -> [WindowInfo] {
        apps
            .flatMap(windowRecords(for:))
            .map(\.info)
            .sorted(by: windowInfoSort)
    }

    private static func focusNextWindow(
        in apps: [WindowAppSnapshot],
        frontmostProcessIdentifier: pid_t?
    ) -> WindowFocusResult {
        let records = apps
            .flatMap(windowRecords(for:))
            .sorted { lhs, rhs in
                windowInfoSort(lhs.info, rhs.info)
            }

        guard !records.isEmpty else {
            return .noWindows
        }

        let selectedIndex: Int
        if let currentIndex = currentWindowIndex(
            in: records,
            frontmostProcessIdentifier: frontmostProcessIdentifier
        ) {
            selectedIndex = nextIndex(after: currentIndex, in: records)
        } else {
            selectedIndex = records.startIndex
        }

        let selectedRecord = records[selectedIndex]
        focus(record: selectedRecord)

        return .focused(selectedRecord.info)
    }

    private static func focus(window targetWindow: WindowInfo, in apps: [WindowAppSnapshot]) -> WindowFocusResult {
        let records = apps.flatMap(windowRecords(for:))

        guard let selectedRecord = matchingRecord(for: targetWindow, in: records) else {
            return .failed(L10n.tr("error.windowNoLongerReadable"))
        }

        focus(record: selectedRecord)
        return .focused(selectedRecord.info)
    }

    private static func matchingRecord(
        for targetWindow: WindowInfo,
        in records: [WindowRecord]
    ) -> WindowRecord? {
        records.first(where: { $0.info.id == targetWindow.id })
            ?? records.first(where: { record in
                record.info.processIdentifier == targetWindow.processIdentifier
                    && record.info.title == targetWindow.title
            })
            ?? records.first(where: { record in
                record.info.processIdentifier == targetWindow.processIdentifier
            })
    }

    private static func currentWindowIndex(
        in records: [WindowRecord],
        frontmostProcessIdentifier: pid_t?
    ) -> Array<WindowRecord>.Index? {
        if let frontmostProcessIdentifier,
           let focusedFrontmostIndex = records.firstIndex(where: { record in
               record.info.processIdentifier == frontmostProcessIdentifier && record.info.isFocused
           }) {
            return focusedFrontmostIndex
        }

        if let frontmostProcessIdentifier,
           let frontmostIndex = records.firstIndex(where: { record in
               record.info.processIdentifier == frontmostProcessIdentifier
           }) {
            return frontmostIndex
        }

        return records.firstIndex(where: { $0.info.isFocused })
    }

    private static func nextIndex(
        after index: Array<WindowRecord>.Index,
        in records: [WindowRecord]
    ) -> Array<WindowRecord>.Index {
        let nextIndex = records.index(after: index)
        return nextIndex == records.endIndex ? records.startIndex : nextIndex
    }

    private static func windowRecords(for app: WindowAppSnapshot) -> [WindowRecord] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let focusedWindow = copyAttribute("AXFocusedWindow", from: appElement)
        let windowElements = copyAttribute("AXWindows", from: appElement) as? [AXUIElement] ?? []

        return windowElements.compactMap { windowElement in
            let title = copyAttribute("AXTitle", from: windowElement) as? String ?? ""
            let isMinimized = copyAttribute("AXMinimized", from: windowElement) as? Bool ?? false
            let frame = frame(for: windowElement)
            let isFocused = focusedWindow.map { CFEqual($0, windowElement) } ?? false

            let windowInfo = WindowInfo(
                appName: app.appName,
                bundleIdentifier: app.bundleIdentifier,
                appURL: app.bundleURL,
                processIdentifier: app.processIdentifier,
                title: title,
                isMinimized: isMinimized,
                frame: frame,
                isFocused: isFocused
            )

            return WindowRecord(info: windowInfo, element: windowElement)
        }
    }

    private static func focus(record: WindowRecord) {
        let appElement = AXUIElementCreateApplication(record.info.processIdentifier)

        if record.info.isMinimized {
            AXUIElementSetAttributeValue(record.element, "AXMinimized" as CFString, kCFBooleanFalse)
        }

        AXUIElementSetAttributeValue(appElement, "AXFrontmost" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(appElement, "AXFocusedWindow" as CFString, record.element)
        AXUIElementSetAttributeValue(record.element, "AXMain" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(record.element, "AXFocused" as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(record.element, "AXRaise" as CFString)
    }

    private static func windowInfoSort(_ lhs: WindowInfo, _ rhs: WindowInfo) -> Bool {
        let appComparison = lhs.appName.localizedCaseInsensitiveCompare(rhs.appName)
        if appComparison != .orderedSame {
            return appComparison == .orderedAscending
        }

        let titleComparison = lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle)
        if titleComparison != .orderedSame {
            return titleComparison == .orderedAscending
        }

        return lhs.processIdentifier < rhs.processIdentifier
    }

    private static func frame(for windowElement: AXUIElement) -> CGRect? {
        guard
            let position = pointAttribute("AXPosition", from: windowElement),
            let size = sizeAttribute("AXSize", from: windowElement)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private static func pointAttribute(_ attribute: String, from element: AXUIElement) -> CGPoint? {
        guard
            let rawValue = copyAttribute(attribute, from: element),
            CFGetTypeID(rawValue) == AXValueGetTypeID()
        else {
            return nil
        }

        let value = rawValue as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else {
            return nil
        }

        return point
    }

    private static func sizeAttribute(_ attribute: String, from element: AXUIElement) -> CGSize? {
        guard
            let rawValue = copyAttribute(attribute, from: element),
            CFGetTypeID(rawValue) == AXValueGetTypeID()
        else {
            return nil
        }

        let value = rawValue as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else {
            return nil
        }

        return size
    }

    private static func copyAttribute(_ attribute: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        guard result == .success else {
            return nil
        }

        return value
    }
}

private struct WindowAppSnapshot: Sendable {
    let appName: String
    let bundleIdentifier: String
    let bundleURL: URL?
    let processIdentifier: pid_t

    init?(app: NSRunningApplication) {
        guard
            app.activationPolicy == .regular,
            let appName = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines),
            !appName.isEmpty,
            let bundleIdentifier = app.bundleIdentifier,
            app.processIdentifier > 0
        else {
            return nil
        }

        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        bundleURL = app.bundleURL
        processIdentifier = app.processIdentifier
    }
}

private struct WindowRecord {
    let info: WindowInfo
    let element: AXUIElement
}
