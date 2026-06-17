import ApplicationServices
import Foundation

enum EventTapError: LocalizedError {
    case accessibilityPermissionMissing
    case couldNotCreateEventTap
    case couldNotCreateRunLoopSource

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            "Accessibility permission is required."
        case .couldNotCreateEventTap:
            "Could not create keyboard event tap."
        case .couldNotCreateRunLoopSource:
            "Could not create event tap run loop source."
        }
    }
}

final class EventTapController {
    var onEvent: (@MainActor (KeyEvent) -> Void)?
    var onShortcut: (@MainActor (KeyShortcut) -> Void)?
    var onRightCommandChanged: (@MainActor (Bool) -> Void)?
    var onWindowSearchKeyAction: (@MainActor (WindowSearchKeyAction) -> Void)?
    var isWindowSearchActive = false
    var keyMappingMode: KeyMappingMode = .activeLayout

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var rightCommandHeld = false
    private var rightOptionHeld = false
    private var consumedKeyCodes = Set<Int64>()
    private var modifierReconciliationWorkItem: DispatchWorkItem?

    var isRunning: Bool {
        guard let eventTap else {
            return false
        }

        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start() throws {
        if isRunning {
            return
        }

        guard AccessibilityPermission.isTrusted else {
            throw EventTapError.accessibilityPermissionMissing
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw EventTapError.couldNotCreateEventTap
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw EventTapError.couldNotCreateRunLoopSource
        }

        eventTap = tap
        runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        AppLog.hotkeys.info("Keyboard event tap started")
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        modifierReconciliationWorkItem?.cancel()
        modifierReconciliationWorkItem = nil
        resetRightCommandState()
        rightOptionHeld = false
        AppLog.hotkeys.info("Keyboard event tap stopped")
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

            emit(KeyEvent(kind: .tapDisabled, keyCode: -1, rawFlags: 0, timestamp: Date()))
            resetRightCommandState()
            rightOptionHeld = false
            return Unmanaged.passUnretained(event)
        }

        let keyEvent = KeyEvent(
            kind: KeyEventKind(type: type),
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            rawFlags: event.flags.rawValue,
            timestamp: Date()
        )

        emit(keyEvent)
        reconcileModifierState(from: keyEvent)

        if keyEvent.kind == .flagsChanged, keyEvent.isRightCommandKey {
            let wasHeld = rightCommandHeld
            rightCommandHeld = keyEvent.commandDown
            if !rightCommandHeld {
                rightOptionHeld = false
                consumedKeyCodes.removeAll()
            }

            if wasHeld != rightCommandHeld {
                emitRightCommandChanged(rightCommandHeld)
            }

            return Unmanaged.passUnretained(event)
        }

        if keyEvent.kind == .flagsChanged, keyEvent.isRightOptionKey {
            rightOptionHeld = keyEvent.optionDown
            return Unmanaged.passUnretained(event)
        }

        if keyEvent.kind == .keyUp, consumedKeyCodes.remove(keyEvent.keyCode) != nil {
            return nil
        }

        if keyEvent.kind == .keyDown, isWindowSearchActive {
            if handleWindowSearchKeyDown(keyEvent, event: event) {
                return nil
            }
        }

        if keyEvent.kind == .keyDown,
           rightCommandHeld,
           event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
           keyEvent.keyCode == KeyCode.tab {
            consumedKeyCodes.insert(keyEvent.keyCode)
            emit(KeyShortcut(kind: .cycleWindow, letter: "\t", keyCode: keyEvent.keyCode, timestamp: Date()))
            scheduleModifierStateReconciliation()
            return nil
        }

        if keyEvent.kind == .keyDown,
           rightCommandHeld,
           event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
           keyEvent.keyCode == KeyCode.space {
            consumedKeyCodes.insert(keyEvent.keyCode)
            emit(KeyShortcut(kind: .openWindowSearch, letter: " ", keyCode: keyEvent.keyCode, timestamp: Date()))
            scheduleModifierStateReconciliation()
            return nil
        }

        if keyEvent.kind == .keyDown,
           rightCommandHeld,
           event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
           let letter = KeyboardLayout.letter(for: keyEvent.keyCode, mode: keyMappingMode) {
            consumedKeyCodes.insert(keyEvent.keyCode)
            let shortcutKind: KeyShortcutKind = rightOptionHeld ? .assign : .activate
            emit(KeyShortcut(kind: shortcutKind, letter: letter, keyCode: keyEvent.keyCode, timestamp: Date()))
            scheduleModifierStateReconciliation()
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleWindowSearchKeyDown(_ keyEvent: KeyEvent, event: CGEvent) -> Bool {
        if shouldPassThroughSystemShortcut(event, keyEvent: keyEvent) {
            return false
        }

        if rightCommandHeld,
           event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
           keyEvent.keyCode == KeyCode.space {
            consumedKeyCodes.insert(keyEvent.keyCode)
            emit(KeyShortcut(kind: .openWindowSearch, letter: " ", keyCode: keyEvent.keyCode, timestamp: Date()))
            scheduleModifierStateReconciliation()
            return true
        }

        switch keyEvent.keyCode {
        case KeyCode.arrowUp:
            emit(.moveUp)
            return true
        case KeyCode.arrowDown:
            emit(.moveDown)
            return true
        case KeyCode.return, KeyCode.keypadEnter:
            emit(.submit)
            return true
        case KeyCode.escape:
            emit(.close)
            return true
        case KeyCode.delete:
            emit(.deleteBackward)
            return true
        default:
            break
        }

        if let text = printableText(from: event) {
            emit(.insertText(text))
            return true
        }

        if let letter = KeyboardLayout.letter(for: keyEvent.keyCode, mode: keyMappingMode) {
            emit(.insertText(String(letter)))
            return true
        }

        return false
    }

    private func shouldPassThroughSystemShortcut(_ event: CGEvent, keyEvent: KeyEvent) -> Bool {
        let flags = event.flags

        if flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            return true
        }

        if flags.contains(.maskCommand), !rightCommandHeld {
            return true
        }

        return false
    }

    private func printableText(from event: CGEvent) -> String? {
        var actualLength = 0
        var chars = [UniChar](repeating: 0, count: 8)
        let textEvent = event.copy() ?? event
        textEvent.flags.remove(.maskCommand)

        textEvent.keyboardGetUnicodeString(
            maxStringLength: chars.count,
            actualStringLength: &actualLength,
            unicodeString: &chars
        )

        guard actualLength > 0 else {
            return nil
        }

        let scalars = chars.prefix(actualLength).compactMap(UnicodeScalar.init)
        let text = String(String.UnicodeScalarView(scalars))

        guard !text.isEmpty,
              text.rangeOfCharacter(from: .controlCharacters) == nil,
              text.rangeOfCharacter(from: .newlines) == nil else {
            return nil
        }

        return text
    }

    private func reconcileModifierState(from event: KeyEvent) {
        guard event.kind == .keyDown || event.kind == .keyUp else {
            return
        }

        if rightCommandHeld, !event.commandDown {
            resetRightCommandState()
        }

        if rightOptionHeld, !event.optionDown {
            rightOptionHeld = false
        }
    }

    private func scheduleModifierStateReconciliation() {
        modifierReconciliationWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.reconcileModifierStateFromSystemFlags()
        }
        modifierReconciliationWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func reconcileModifierStateFromSystemFlags() {
        let flags = CGEventSource.flagsState(.combinedSessionState)

        if rightCommandHeld, !flags.contains(.maskCommand) {
            resetRightCommandState()
        }

        if rightOptionHeld, !flags.contains(.maskAlternate) {
            rightOptionHeld = false
        }
    }

    private func resetRightCommandState() {
        let wasHeld = rightCommandHeld
        rightCommandHeld = false
        consumedKeyCodes.removeAll()

        if wasHeld {
            emitRightCommandChanged(false)
        }
    }

    private func emit(_ event: KeyEvent) {
        guard let onEvent else {
            return
        }

        Task { @MainActor in
            onEvent(event)
        }
    }

    private func emit(_ shortcut: KeyShortcut) {
        guard let onShortcut else {
            return
        }

        Task { @MainActor in
            onShortcut(shortcut)
        }
    }

    private func emit(_ action: WindowSearchKeyAction) {
        guard let onWindowSearchKeyAction else {
            return
        }

        if Thread.isMainThread {
            MainActor.assumeIsolated {
                onWindowSearchKeyAction(action)
            }
            return
        }

        Task { @MainActor in
            onWindowSearchKeyAction(action)
        }
    }

    private func emitRightCommandChanged(_ isHeld: Bool) {
        guard let onRightCommandChanged else {
            return
        }

        Task { @MainActor in
            onRightCommandChanged(isHeld)
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handle(proxy: proxy, type: type, event: event)
}

private extension KeyEventKind {
    init(type: CGEventType) {
        switch type {
        case .keyDown:
            self = .keyDown
        case .keyUp:
            self = .keyUp
        case .flagsChanged:
            self = .flagsChanged
        default:
            self = .unknown
        }
    }
}
