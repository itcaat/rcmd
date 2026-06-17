import ApplicationServices
import Foundation

enum KeyEventKind: String, Sendable {
    case keyDown
    case keyUp
    case flagsChanged
    case tapDisabled
    case unknown
}

struct KeyEvent: Sendable, Equatable {
    let kind: KeyEventKind
    let keyCode: Int64
    let rawFlags: UInt64
    let timestamp: Date

    var commandDown: Bool {
        CGEventFlags(rawValue: rawFlags).contains(.maskCommand)
    }

    var optionDown: Bool {
        CGEventFlags(rawValue: rawFlags).contains(.maskAlternate)
    }

    var isRightCommandKey: Bool {
        keyCode == KeyCode.rightCommand
    }

    var isLeftCommandKey: Bool {
        keyCode == KeyCode.leftCommand
    }

    var isRightOptionKey: Bool {
        keyCode == KeyCode.rightOption
    }

    var isLeftOptionKey: Bool {
        keyCode == KeyCode.leftOption
    }

    var displayDescription: String {
        let side: String

        if isRightCommandKey {
            side = "right-command"
        } else if isLeftCommandKey {
            side = "left-command"
        } else if isRightOptionKey {
            side = "right-option"
        } else if isLeftOptionKey {
            side = "left-option"
        } else if keyCode == KeyCode.tab {
            side = "tab"
        } else if keyCode == KeyCode.space {
            side = "space"
        } else if let letter = KeyboardLayout.letter(for: keyCode) {
            side = "key-\(String(letter).uppercased())"
        } else {
            side = "key-\(keyCode)"
        }

        return "\(kind.rawValue) \(side) flags=\(rawFlags)"
    }
}

enum KeyCode {
    static let leftCommand: Int64 = 55
    static let rightCommand: Int64 = 54
    static let leftOption: Int64 = 58
    static let rightOption: Int64 = 61
    static let tab: Int64 = 48
    static let space: Int64 = 49
}
