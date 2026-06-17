import Foundation

enum WindowSearchFilter {
    static func filteredWindows(_ windows: [WindowInfo], query: String) -> [WindowInfo] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = normalizedQuery
            .lowercased()
            .split(separator: " ")
            .map(String.init)

        guard !tokens.isEmpty else {
            return windows
        }

        return windows.filter { window in
            let searchableText = "\(window.appName) \(window.displayTitle) \(window.bundleIdentifier)"
                .lowercased()

            return tokens.allSatisfy { searchableText.contains($0) }
        }
    }

    static func displayedWindows(_ windows: [WindowInfo], query: String, limit: Int = 18) -> [WindowInfo] {
        Array(filteredWindows(windows, query: query).prefix(limit))
    }
}
