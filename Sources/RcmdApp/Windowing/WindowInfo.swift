import CoreGraphics
import Foundation

struct WindowInfo: Identifiable, Equatable, Sendable {
    let appName: String
    let bundleIdentifier: String
    let appURL: URL?
    let processIdentifier: pid_t
    let title: String
    let isMinimized: Bool
    let frame: CGRect?
    let isFocused: Bool

    var id: String {
        let frameKey = frame.map { "\($0.origin.x),\($0.origin.y),\($0.width),\($0.height)" } ?? "noframe"
        return "\(processIdentifier)-\(title)-\(frameKey)"
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "(Untitled)" : trimmedTitle
    }

    var detailText: String {
        var parts: [String] = []

        if isFocused {
            parts.append("focused")
        }

        if isMinimized {
            parts.append("minimized")
        }

        if let frame {
            parts.append("\(Int(frame.width))x\(Int(frame.height)) @ \(Int(frame.origin.x)),\(Int(frame.origin.y))")
        }

        if parts.isEmpty {
            return bundleIdentifier
        }

        return parts.joined(separator: ", ")
    }
}

enum WindowFocusResult: Sendable, Equatable {
    case focused(WindowInfo)
    case noWindows
    case failed(String)

    var displayMessage: String {
        switch self {
        case .focused(let window):
            "Focused \(window.appName): \(window.displayTitle)."
        case .noWindows:
            "No readable windows found."
        case .failed(let message):
            "Window focus failed: \(message)"
        }
    }
}
