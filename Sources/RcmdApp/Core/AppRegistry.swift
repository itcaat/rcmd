import AppKit
import ApplicationServices
import Foundation

struct AppAssignment: Identifiable, Sendable, Equatable {
    let letter: Character
    let appName: String
    let bundleIdentifier: String
    let appURL: URL?
    let isRunning: Bool
    let isManual: Bool

    var id: String {
        "\(letter)-\(bundleIdentifier)"
    }

    var displayText: String {
        let state = isRunning ? "running" : "closed"
        let source = isManual ? ", manual" : ""
        return "\(String(letter).uppercased()) -> \(appName) (\(state)\(source))"
    }
}

struct AppCatalogEntry: Identifiable, Sendable, Equatable {
    let appName: String
    let bundleIdentifier: String
    let appURL: URL
    let isRunning: Bool

    var id: String {
        bundleIdentifier
    }

    var displayText: String {
        let state = isRunning ? "running" : "closed"
        return "\(appName) (\(state))"
    }
}

enum AppActivationResult: Sendable, Equatable {
    case focused(AppAssignment)
    case minimized(AppAssignment)
    case launched(AppAssignment)
    case unassigned(Character)
    case failed(AppAssignment, String)

    var assignment: AppAssignment? {
        switch self {
        case .focused(let assignment), .minimized(let assignment), .launched(let assignment), .failed(let assignment, _):
            assignment
        case .unassigned:
            nil
        }
    }

    var displayMessage: String {
        switch self {
        case .focused(let assignment):
            "\(assignment.appName) focused."
        case .minimized(let assignment):
            "\(assignment.appName) active window minimized."
        case .launched(let assignment):
            "\(assignment.appName) launched."
        case .unassigned(let letter):
            "No app assignment for \(String(letter).uppercased())."
        case .failed(let assignment, let message):
            "\(assignment.appName) failed: \(message)"
        }
    }
}

enum ManualAssignmentResult: Sendable, Equatable {
    case assigned(AppAssignment)
    case noActiveApp(Character)
    case failed(Character, String)

    var displayMessage: String {
        switch self {
        case .assigned(let assignment):
            "\(String(assignment.letter).uppercased()) assigned to \(assignment.appName)."
        case .noActiveApp(let letter):
            "No active regular app to assign to \(String(letter).uppercased())."
        case .failed(let letter, let message):
            "Could not assign \(String(letter).uppercased()): \(message)"
        }
    }
}

enum ManualAssignmentRemovalResult: Sendable, Equatable {
    case removed(Character)
    case notAssigned(Character)

    var displayMessage: String {
        switch self {
        case .removed(let letter):
            "\(String(letter).uppercased()) manual assignment removed."
        case .notAssigned(let letter):
            "\(String(letter).uppercased()) has no manual assignment."
        }
    }
}

@MainActor
final class AppRegistry {
    private let workspace: NSWorkspace
    private let assignmentStore: AssignmentStore

    init(workspace: NSWorkspace = .shared, assignmentStore: AssignmentStore) {
        self.workspace = workspace
        self.assignmentStore = assignmentStore
    }

    func currentAssignments() -> [AppAssignment] {
        var assignedLetters = Set<Character>()
        var assignedBundleIdentifiers = Set<String>()
        var assignments: [AppAssignment] = []

        addManualAssignments(
            to: &assignments,
            assignedLetters: &assignedLetters,
            assignedBundleIdentifiers: &assignedBundleIdentifiers
        )
        addRunningAssignments(
            to: &assignments,
            assignedLetters: &assignedLetters,
            assignedBundleIdentifiers: &assignedBundleIdentifiers
        )
        addInstalledAssignments(
            to: &assignments,
            assignedLetters: &assignedLetters,
            assignedBundleIdentifiers: &assignedBundleIdentifiers
        )

        return assignments.sorted { lhs, rhs in
            String(lhs.letter) < String(rhs.letter)
        }
    }

    func appCatalog() -> [AppCatalogEntry] {
        installedApplications().map { app in
            AppCatalogEntry(
                appName: app.appName,
                bundleIdentifier: app.bundleIdentifier,
                appURL: app.appURL,
                isRunning: isRunning(bundleIdentifier: app.bundleIdentifier)
            )
        }
    }

    func focusOrLaunchAssignedApp(for letter: Character) async -> AppActivationResult {
        let normalizedLetter = Character(String(letter).lowercased())
        let assignments = currentAssignments()

        guard let assignment = assignments.first(where: { $0.letter == normalizedLetter }) else {
            return .unassigned(normalizedLetter)
        }

        if let app = workspace.runningApplications.first(where: { runningApp in
            runningApp.bundleIdentifier == assignment.bundleIdentifier
        }) {
            if assignmentStore.minimizeActiveWindowOnRepeatedShortcut,
               workspace.frontmostApplication?.bundleIdentifier == assignment.bundleIdentifier {
                switch minimizeFocusedWindowIfVisible(for: app) {
                case .minimized:
                    AppLog.app.info("Minimized active window for \(assignment.appName, privacy: .public) via repeated \(String(normalizedLetter), privacy: .public)")
                    return .minimized(assignment)
                case .shouldFocus:
                    break
                case .failed(let message):
                    return .failed(assignment, message)
                }
            }

            app.unhide()
            restoreMinimizedWindows(for: app)
            app.activate(options: [.activateAllWindows])
            AppLog.app.info("Focused \(assignment.appName, privacy: .public) for \(String(normalizedLetter), privacy: .public)")
            return .focused(assignment)
        }

        guard let appURL = assignment.appURL else {
            return .failed(assignment, "missing application URL")
        }

        if let launchError = await openApplication(at: appURL) {
            AppLog.app.error("Failed to launch \(assignment.appName, privacy: .public): \(launchError, privacy: .public)")
            return .failed(assignment, launchError)
        }

        AppLog.app.info("Launched \(assignment.appName, privacy: .public) for \(String(normalizedLetter), privacy: .public)")
        return .launched(assignment)
    }

    func assignFrontmostApp(to letter: Character) -> ManualAssignmentResult {
        let normalizedLetter = Character(String(letter).lowercased())

        guard
            let app = workspace.frontmostApplication,
            app.activationPolicy == .regular,
            let bundleIdentifier = app.bundleIdentifier
        else {
            return .noActiveApp(normalizedLetter)
        }

        assignmentStore.set(bundleIdentifier: bundleIdentifier, for: normalizedLetter)

        guard let assignment = assignment(for: normalizedLetter, bundleIdentifier: bundleIdentifier, isManual: true) else {
            return .failed(normalizedLetter, "saved app could not be resolved")
        }

        AppLog.app.info("Assigned \(String(normalizedLetter), privacy: .public) to \(assignment.appName, privacy: .public)")
        return .assigned(assignment)
    }

    func assign(bundleIdentifier: String, to letter: Character) -> ManualAssignmentResult {
        let normalizedLetter = Character(String(letter).lowercased())
        assignmentStore.set(bundleIdentifier: bundleIdentifier, for: normalizedLetter)

        guard let assignment = assignment(for: normalizedLetter, bundleIdentifier: bundleIdentifier, isManual: true) else {
            return .failed(normalizedLetter, "saved app could not be resolved")
        }

        AppLog.app.info("Assigned \(String(normalizedLetter), privacy: .public) to \(assignment.appName, privacy: .public)")
        return .assigned(assignment)
    }

    func removeManualAssignment(for letter: Character) -> ManualAssignmentRemovalResult {
        let normalizedLetter = Character(String(letter).lowercased())

        guard assignmentStore.bundleIdentifier(for: normalizedLetter) != nil else {
            return .notAssigned(normalizedLetter)
        }

        assignmentStore.removeAssignment(for: normalizedLetter)
        AppLog.app.info("Removed manual assignment for \(String(normalizedLetter), privacy: .public)")
        return .removed(normalizedLetter)
    }

    private func addManualAssignments(
        to assignments: inout [AppAssignment],
        assignedLetters: inout Set<Character>,
        assignedBundleIdentifiers: inout Set<String>
    ) {
        for letter in assignmentStore.assignmentsByLetter.keys.sorted(by: { String($0) < String($1) }) {
            guard
                let bundleIdentifier = assignmentStore.bundleIdentifier(for: letter),
                let assignment = assignment(for: letter, bundleIdentifier: bundleIdentifier, isManual: true)
            else {
                continue
            }

            assignedLetters.insert(letter)
            assignedBundleIdentifiers.insert(bundleIdentifier)
            assignments.append(assignment)
        }
    }

    private func addRunningAssignments(
        to assignments: inout [AppAssignment],
        assignedLetters: inout Set<Character>,
        assignedBundleIdentifiers: inout Set<String>
    ) {
        for app in regularRunningApplications() {
            guard
                let appName = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines),
                let bundleIdentifier = app.bundleIdentifier,
                let letter = firstLetter(in: appName),
                !assignedLetters.contains(letter),
                !assignedBundleIdentifiers.contains(bundleIdentifier)
            else {
                continue
            }

            assignedLetters.insert(letter)
            assignedBundleIdentifiers.insert(bundleIdentifier)
            assignments.append(
                AppAssignment(
                    letter: letter,
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    appURL: app.bundleURL,
                    isRunning: true,
                    isManual: false
                )
            )
        }
    }

    private func addInstalledAssignments(
        to assignments: inout [AppAssignment],
        assignedLetters: inout Set<Character>,
        assignedBundleIdentifiers: inout Set<String>
    ) {
        for app in installedApplications() {
            guard
                let letter = firstLetter(in: app.appName),
                !assignedLetters.contains(letter),
                !assignedBundleIdentifiers.contains(app.bundleIdentifier)
            else {
                continue
            }

            assignedLetters.insert(letter)
            assignedBundleIdentifiers.insert(app.bundleIdentifier)
            assignments.append(
                AppAssignment(
                    letter: letter,
                    appName: app.appName,
                    bundleIdentifier: app.bundleIdentifier,
                    appURL: app.appURL,
                    isRunning: isRunning(bundleIdentifier: app.bundleIdentifier),
                    isManual: false
                )
            )
        }
    }

    private func regularRunningApplications() -> [NSRunningApplication] {
        workspace.runningApplications
            .filter { app in
                app.activationPolicy == .regular
                    && app.bundleIdentifier != nil
                    && app.localizedName != nil
            }
            .sorted { lhs, rhs in
                (lhs.localizedName ?? "").localizedCaseInsensitiveCompare(rhs.localizedName ?? "") == .orderedAscending
            }
    }

    private func installedApplications() -> [InstalledApplication] {
        var appsByBundleID: [String: InstalledApplication] = [:]

        for directory in applicationSearchDirectories() {
            for appURL in appBundleURLs(in: directory) {
                guard
                    let bundle = Bundle(url: appURL),
                    let bundleIdentifier = bundle.bundleIdentifier,
                    let appName = appDisplayName(bundle: bundle, appURL: appURL)
                else {
                    continue
                }

                let app = InstalledApplication(
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    appURL: appURL
                )

                if let existing = appsByBundleID[bundleIdentifier] {
                    if appSortKey(app) < appSortKey(existing) {
                        appsByBundleID[bundleIdentifier] = app
                    }
                } else {
                    appsByBundleID[bundleIdentifier] = app
                }
            }
        }

        return appsByBundleID.values.sorted { lhs, rhs in
            lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
        }
    }

    private func assignment(
        for letter: Character,
        bundleIdentifier: String,
        isManual: Bool
    ) -> AppAssignment? {
        if let runningApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            let appName = runningApp.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? bundleIdentifier

            return AppAssignment(
                letter: letter,
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                appURL: runningApp.bundleURL,
                isRunning: true,
                isManual: isManual
            )
        }

        if let installedApp = installedApplications().first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return AppAssignment(
                letter: letter,
                appName: installedApp.appName,
                bundleIdentifier: bundleIdentifier,
                appURL: installedApp.appURL,
                isRunning: false,
                isManual: isManual
            )
        }

        return AppAssignment(
            letter: letter,
            appName: bundleIdentifier,
            bundleIdentifier: bundleIdentifier,
            appURL: nil,
            isRunning: false,
            isManual: isManual
        )
    }

    private func applicationSearchDirectories() -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    private func appBundleURLs(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isApplicationKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard
                let url = item as? URL,
                url.pathExtension == "app"
            else {
                return nil
            }

            return url
        }
    }

    private func appDisplayName(bundle: Bundle, appURL: URL) -> String? {
        let info = bundle.localizedInfoDictionary ?? bundle.infoDictionary ?? [:]
        let rawName = info["CFBundleDisplayName"] as? String
            ?? info["CFBundleName"] as? String
            ?? appURL.deletingPathExtension().lastPathComponent
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        return name.isEmpty ? nil : name
    }

    private func isRunning(bundleIdentifier: String) -> Bool {
        workspace.runningApplications.contains { app in
            app.bundleIdentifier == bundleIdentifier
        }
    }

    private func restoreMinimizedWindows(for app: NSRunningApplication) {
        guard AccessibilityPermission.isTrusted, app.processIdentifier > 0 else {
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let windowElements = copyAttribute("AXWindows", from: appElement) as? [AXUIElement] else {
            return
        }

        for windowElement in windowElements {
            guard copyAttribute("AXMinimized", from: windowElement) as? Bool == true else {
                continue
            }

            AXUIElementSetAttributeValue(windowElement, "AXMinimized" as CFString, kCFBooleanFalse)
        }
    }

    private func minimizeFocusedWindowIfVisible(for app: NSRunningApplication) -> ActiveWindowMinimizeResult {
        guard AccessibilityPermission.isTrusted, app.processIdentifier > 0 else {
            return .failed("Accessibility permission is required")
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let windowValue = copyAttribute("AXFocusedWindow", from: appElement)
            ?? copyAttribute("AXMainWindow", from: appElement) else {
            return .shouldFocus
        }

        let windowElement = windowValue as! AXUIElement

        if copyAttribute("AXMinimized", from: windowElement) as? Bool == true {
            return .shouldFocus
        }

        let result = AXUIElementSetAttributeValue(windowElement, "AXMinimized" as CFString, kCFBooleanTrue)
        return result == .success ? .minimized : .failed("could not minimize active window")
    }

    private func copyAttribute(_ attribute: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        guard result == .success else {
            return nil
        }

        return value
    }

    private func appSortKey(_ app: InstalledApplication) -> String {
        app.appURL.path
    }

    private func firstLetter(in appName: String) -> Character? {
        appName
            .lowercased()
            .first { character in
                character.isLetter
            }
    }
}

private struct InstalledApplication: Sendable, Equatable {
    let appName: String
    let bundleIdentifier: String
    let appURL: URL
}

private enum ActiveWindowMinimizeResult {
    case minimized
    case shouldFocus
    case failed(String)
}

private func openApplication(
    at appURL: URL
) async -> String? {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.addsToRecentItems = false

    return await withCheckedContinuation { continuation in
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            continuation.resume(returning: error?.localizedDescription)
        }
    }
}
