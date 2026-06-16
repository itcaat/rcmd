import Foundation

enum KeyShortcutKind: String, Sendable, Equatable {
    case activate
    case assign
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
        }
    }
}
