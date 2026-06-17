import AppKit
import SwiftUI

struct SearchTextField: NSViewRepresentable {
    @Binding var text: String

    let isActive: Bool
    let placeholder: String
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSubmit: () -> Void
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.usesSingleLineMode = true
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        context.coordinator.onMoveUp = onMoveUp
        context.coordinator.onMoveDown = onMoveDown
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onEscape = onEscape

        if let editor = textField.currentEditor() {
            if editor.string != text {
                editor.string = text
                editor.selectedRange = NSRange(location: editor.string.utf16.count, length: 0)
            }
        } else if textField.stringValue != text {
            textField.stringValue = text
        }

        textField.placeholderString = placeholder
        textField.isEditable = isActive
        textField.isSelectable = isActive
        textField.textColor = isActive ? .labelColor : .secondaryLabelColor

        DispatchQueue.main.async {
            guard let window = textField.window else {
                return
            }

            if isActive {
                window.makeFirstResponder(textField)
            } else if let editor = textField.currentEditor(), window.firstResponder === editor {
                window.makeFirstResponder(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        var onMoveUp: (() -> Void)?
        var onMoveDown: (() -> Void)?
        var onSubmit: (() -> Void)?
        var onEscape: (() -> Void)?

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }

            text = textField.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                onMoveUp?()
                return true
            case #selector(NSResponder.moveDown(_:)):
                onMoveDown?()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                onSubmit?()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                onEscape?()
                return true
            default:
                return false
            }
        }
    }
}
