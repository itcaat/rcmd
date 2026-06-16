import AppKit
import Foundation

struct AppAssignment: Identifiable, Sendable, Equatable {
    let letter: Character
    let appName: String
    let bundleIdentifier: String

    var id: String {
        "\(letter)-\(bundleIdentifier)"
    }

    var displayText: String {
        "\(String(letter).uppercased()) -> \(appName)"
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
                    bundleIdentifier: bundleIdentifier
                )
            )
        }

        return assignments.sorted { lhs, rhs in
            String(lhs.letter) < String(rhs.letter)
        }
    }

    func focusAssignedApp(for letter: Character) -> AppAssignment? {
        let normalizedLetter = Character(String(letter).lowercased())
        let assignments = currentAssignments()

        guard let assignment = assignments.first(where: { $0.letter == normalizedLetter }) else {
            return nil
        }

        guard let app = workspace.runningApplications.first(where: { runningApp in
            runningApp.bundleIdentifier == assignment.bundleIdentifier
        }) else {
            return nil
        }

        app.activate(options: [.activateAllWindows])
        AppLog.app.info("Focused \(assignment.appName, privacy: .public) for \(String(normalizedLetter), privacy: .public)")
        return assignment
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

    private func firstLetter(in appName: String) -> Character? {
        appName
            .lowercased()
            .first { character in
                character.isLetter
            }
    }
}
