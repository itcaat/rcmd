import Foundation

enum KeyShortcutKind: String, Sendable, Equatable {
    case activate
    case assign
    case cycleWindow
    case openWindowSearch
}

struct KeyShortcut: Sendable, Equatable {
    let kind: KeyShortcutKind
    let letter: Character
    let keyCode: Int64
    let timestamp: Date

    var displayDescription: String {
        switch kind {
        case .activate:
            "right-cmd+\(String(letter).uppercased())"
        case .assign:
            "right-cmd+right-option+\(String(letter).uppercased())"
        case .cycleWindow:
            "right-cmd+tab"
        case .openWindowSearch:
            "right-cmd+space"
        }
    }
}

enum WindowSearchKeyAction: Sendable, Equatable {
    case moveUp
    case moveDown
    case submit
    case close
    case deleteBackward
    case insertText(String)
}
