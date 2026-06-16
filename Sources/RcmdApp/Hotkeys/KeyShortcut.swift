import Foundation

struct KeyShortcut: Sendable, Equatable {
    let letter: Character
    let keyCode: Int64
    let timestamp: Date

    var displayDescription: String {
        "right-cmd+\(String(letter).uppercased())"
    }
}
