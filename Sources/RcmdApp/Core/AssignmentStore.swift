import Foundation

@MainActor
final class AssignmentStore {
    private(set) var assignmentsByLetter: [Character: String] = [:]

    private let configURL: URL

    init(configURL: URL = AssignmentStore.defaultConfigURL()) {
        self.configURL = configURL
        load()
    }

    func bundleIdentifier(for letter: Character) -> String? {
        assignmentsByLetter[normalize(letter)]
    }

    func set(bundleIdentifier: String, for letter: Character) {
        assignmentsByLetter[normalize(letter)] = bundleIdentifier
        save()
    }

    func removeAssignment(for letter: Character) {
        assignmentsByLetter.removeValue(forKey: normalize(letter))
        save()
    }

    private func load() {
        guard
            let contents = try? String(contentsOf: configURL, encoding: .utf8),
            !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            assignmentsByLetter = [:]
            return
        }

        var parsedAssignments: [Character: String] = [:]
        var inAssignmentsSection = false

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            if line == "assignments:" {
                inAssignmentsSection = true
                continue
            }

            guard inAssignmentsSection else {
                continue
            }

            guard
                let separatorIndex = line.firstIndex(of: ":"),
                let letter = line[..<separatorIndex].trimmingCharacters(in: .whitespaces).first
            else {
                continue
            }

            let valueStart = line.index(after: separatorIndex)
            let rawValue = line[valueStart...].trimmingCharacters(in: .whitespaces)
            let bundleIdentifier = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            if !bundleIdentifier.isEmpty {
                parsedAssignments[normalize(letter)] = bundleIdentifier
            }
        }

        assignmentsByLetter = parsedAssignments
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var lines = [
                "# rcmd configuration",
                "assignments:"
            ]

            for letter in assignmentsByLetter.keys.sorted(by: { String($0) < String($1) }) {
                if let bundleIdentifier = assignmentsByLetter[letter] {
                    lines.append("  \(letter): \(bundleIdentifier)")
                }
            }

            lines.append("")
            try lines.joined(separator: "\n").write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            AppLog.app.error("Failed to save assignments: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func normalize(_ letter: Character) -> Character {
        Character(String(letter).lowercased())
    }

    static func defaultConfigURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("rcmd", isDirectory: true)
            .appendingPathComponent("config.yaml")
    }
}
