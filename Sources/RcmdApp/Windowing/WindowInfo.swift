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
        return trimmedTitle.isEmpty ? L10n.tr("window.untitled") : trimmedTitle
    }

    var detailText: String {
        var parts: [String] = []

        if isFocused {
            parts.append(L10n.tr("window.focused"))
        }

        if isMinimized {
            parts.append(L10n.tr("window.minimized"))
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
            L10n.tr("windowFocus.focused", window.appName, window.displayTitle)
        case .noWindows:
            L10n.tr("windowFocus.noWindows")
        case .failed(let message):
            L10n.tr("windowFocus.failed", message)
        }
    }
}
