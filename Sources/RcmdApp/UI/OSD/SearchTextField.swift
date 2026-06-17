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
        let textField = SearchNSTextField()
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
        let becameActive = isActive && !context.coordinator.wasActive
        context.coordinator.wasActive = isActive

        if let editor = textField.currentEditor() {
            if editor.string != text {
                editor.string = text
                moveCaretToEnd(in: editor)
            }
        } else if textField.stringValue != text {
            textField.stringValue = text
        }

        textField.placeholderString = placeholder
        textField.isEditable = isActive
        textField.isSelectable = isActive
        textField.textColor = isActive ? .labelColor : .secondaryLabelColor

        guard let window = textField.window else {
            return
        }

        if isActive {
            if becameActive || textField.currentEditor() == nil {
                window.makeFirstResponder(textField)
            }

            if becameActive, let editor = textField.currentEditor() {
                moveCaretToEnd(in: editor)
            }
        } else if let editor = textField.currentEditor(), window.firstResponder === editor {
            window.makeFirstResponder(nil)
        }
    }

    private func moveCaretToEnd(in editor: NSText) {
        editor.selectedRange = NSRange(location: editor.string.utf16.count, length: 0)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        var wasActive = false
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

private final class SearchNSTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        moveCaretToEnd()
        return didBecomeFirstResponder
    }

    override func selectText(_ sender: Any?) {
        window?.makeFirstResponder(self)
        moveCaretToEnd()
    }

    private func moveCaretToEnd() {
        guard let editor = currentEditor() else {
            return
        }

        editor.selectedRange = NSRange(location: editor.string.utf16.count, length: 0)
    }
}
