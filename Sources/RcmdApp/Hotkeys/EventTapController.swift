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

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var rightCommandHeld = false
    private var consumedKeyCodes = Set<Int64>()

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
        rightCommandHeld = false
        consumedKeyCodes.removeAll()
        AppLog.hotkeys.info("Keyboard event tap stopped")
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

            emit(KeyEvent(kind: .tapDisabled, keyCode: -1, rawFlags: 0, timestamp: Date()))
            return Unmanaged.passUnretained(event)
        }

        let keyEvent = KeyEvent(
            kind: KeyEventKind(type: type),
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            rawFlags: event.flags.rawValue,
            timestamp: Date()
        )

        emit(keyEvent)

        if keyEvent.kind == .flagsChanged, keyEvent.isRightCommandKey {
            rightCommandHeld = keyEvent.commandDown
            if !rightCommandHeld {
                consumedKeyCodes.removeAll()
            }

            return Unmanaged.passUnretained(event)
        }

        if keyEvent.kind == .keyUp, consumedKeyCodes.remove(keyEvent.keyCode) != nil {
            return nil
        }

        if keyEvent.kind == .keyDown,
           rightCommandHeld,
           event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
           let letter = KeyboardLayout.letter(for: keyEvent.keyCode) {
            consumedKeyCodes.insert(keyEvent.keyCode)
            emit(KeyShortcut(letter: letter, keyCode: keyEvent.keyCode, timestamp: Date()))
            return nil
        }

        return Unmanaged.passUnretained(event)
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
