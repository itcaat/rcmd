import AppKit
import Foundation

struct AppAssignment: Identifiable, Sendable, Equatable {
    let letter: Character
    let appName: String
    let bundleIdentifier: String
    let appURL: URL?
    let isRunning: Bool

    var id: String {
        "\(letter)-\(bundleIdentifier)"
    }

    var displayText: String {
        let state = isRunning ? "running" : "closed"
        return "\(String(letter).uppercased()) -> \(appName) (\(state))"
    }
}

enum AppActivationResult: Sendable, Equatable {
    case focused(AppAssignment)
    case launched(AppAssignment)
    case unassigned(Character)
    case failed(AppAssignment, String)

    var assignment: AppAssignment? {
        switch self {
        case .focused(let assignment), .launched(let assignment), .failed(let assignment, _):
            assignment
        case .unassigned:
            nil
        }
    }

    var displayMessage: String {
        switch self {
        case .focused(let assignment):
            "\(assignment.appName) focused."
        case .launched(let assignment):
            "\(assignment.appName) launched."
        case .unassigned(let letter):
            "No app assignment for \(String(letter).uppercased())."
        case .failed(let assignment, let message):
            "\(assignment.appName) failed: \(message)"
        }
    }
}

@MainActor
final class AppRegistry {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func currentAssignments() -> [AppAssignment] {
        var assignedLetters = Set<Character>()
        var assignments: [AppAssignment] = []

        addRunningAssignments(to: &assignments, assignedLetters: &assignedLetters)
        addInstalledAssignments(to: &assignments, assignedLetters: &assignedLetters)

        return assignments.sorted { lhs, rhs in
            String(lhs.letter) < String(rhs.letter)
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
            app.activate(options: [.activateAllWindows])
            AppLog.app.info("Focused \(assignment.appName, privacy: .public) for \(String(normalizedLetter), privacy: .public)")
            return .focused(assignment)
        }

        guard let appURL = assignment.appURL else {
            return .failed(assignment, "missing application URL")
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false

        return await withCheckedContinuation { continuation in
            workspace.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error {
                    AppLog.app.error("Failed to launch \(assignment.appName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: .failed(assignment, error.localizedDescription))
                } else {
                    AppLog.app.info("Launched \(assignment.appName, privacy: .public) for \(String(normalizedLetter), privacy: .public)")
                    continuation.resume(returning: .launched(assignment))
                }
            }
        }
    }

    private func addRunningAssignments(
        to assignments: inout [AppAssignment],
        assignedLetters: inout Set<Character>
    ) {
        for app in regularRunningApplications() {
            guard
                let appName = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines),
                let bundleIdentifier = app.bundleIdentifier,
                let letter = firstLetter(in: appName),
                !assignedLetters.contains(letter)
            else {
                continue
            }

            assignedLetters.insert(letter)
            assignments.append(
                AppAssignment(
                    letter: letter,
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    appURL: app.bundleURL,
                    isRunning: true
                )
            )
        }
    }

    private func addInstalledAssignments(
        to assignments: inout [AppAssignment],
        assignedLetters: inout Set<Character>
    ) {
        for app in installedApplications() {
            guard
                let letter = firstLetter(in: app.appName),
                !assignedLetters.contains(letter)
            else {
                continue
            }

            assignedLetters.insert(letter)
            assignments.append(
                AppAssignment(
                    letter: letter,
                    appName: app.appName,
                    bundleIdentifier: app.bundleIdentifier,
                    appURL: app.appURL,
                    isRunning: isRunning(bundleIdentifier: app.bundleIdentifier)
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
