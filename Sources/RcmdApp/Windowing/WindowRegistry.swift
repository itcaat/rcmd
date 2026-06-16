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

    private static func readWindows(for apps: [WindowAppSnapshot]) -> [WindowInfo] {
        apps
            .flatMap(windows(for:))
            .sorted { lhs, rhs in
                if lhs.isFocused != rhs.isFocused {
                    return lhs.isFocused
                }

                let appComparison = lhs.appName.localizedCaseInsensitiveCompare(rhs.appName)
                if appComparison != .orderedSame {
                    return appComparison == .orderedAscending
                }

                return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
            }
    }

    private static func windows(for app: WindowAppSnapshot) -> [WindowInfo] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let focusedWindow = copyAttribute("AXFocusedWindow", from: appElement)
        let windowElements = copyAttribute("AXWindows", from: appElement) as? [AXUIElement] ?? []

        return windowElements.compactMap { windowElement in
            let title = copyAttribute("AXTitle", from: windowElement) as? String ?? ""
            let isMinimized = copyAttribute("AXMinimized", from: windowElement) as? Bool ?? false
            let frame = frame(for: windowElement)
            let isFocused = focusedWindow.map { CFEqual($0, windowElement) } ?? false

            return WindowInfo(
                appName: app.appName,
                bundleIdentifier: app.bundleIdentifier,
                appURL: app.bundleURL,
                processIdentifier: app.processIdentifier,
                title: title,
                isMinimized: isMinimized,
                frame: frame,
                isFocused: isFocused
            )
        }
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
