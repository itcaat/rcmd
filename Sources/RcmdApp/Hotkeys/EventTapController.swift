import ApplicationServices
import Foundation

enum EventTapError: LocalizedError {
    case accessibilityPermissionMissing
    case couldNotCreateEventTap
    case couldNotCreateRunLoopSource

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            L10n.tr("error.accessibilityPermissionRequired")
        case .couldNotCreateEventTap:
            L10n.tr("error.couldNotCreateEventTap")
        case .couldNotCreateRunLoopSource:
            L10n.tr("error.couldNotCreateRunLoopSource")
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
    private var router = KeyEventRouter()
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
        if router.resetRightCommandState() {
            emitRightCommandChanged(false)
        }
        router.resetAll()
        AppLog.hotkeys.info("Keyboard event tap stopped")
    }

    fileprivate func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

            emit(KeyEvent(kind: .tapDisabled, keyCode: -1, rawFlags: 0, timestamp: Date()))
            if router.resetRightCommandState() {
                emitRightCommandChanged(false)
            }
            router.resetAll()
            return Unmanaged.passUnretained(event)
        }

        let keyEvent = KeyEvent(
            kind: KeyEventKind(type: type),
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            rawFlags: event.flags.rawValue,
            timestamp: Date()
        )

        emit(keyEvent)

        let decision = router.route(
            KeyEventRoutingInput(
                event: keyEvent,
                isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                isWindowSearchActive: isWindowSearchActive,
                keyMappingMode: keyMappingMode,
                printableText: keyEvent.kind == .keyDown ? printableText(from: event) : nil
            )
        )

        switch decision {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .suppress:
            return nil
        case .shortcut(let shortcut):
            emit(shortcut)
            scheduleModifierStateReconciliation()
            return nil
        case .windowSearchAction(let action):
            emit(action)
            return nil
        case .rightCommandChanged(let isHeld):
            emitRightCommandChanged(isHeld)
            return Unmanaged.passUnretained(event)
        }
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

        if router.reconcileModifierStateFromSystemFlags(flags) {
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
