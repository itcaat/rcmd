import ApplicationServices
import XCTest
@testable import RcmdApp

final class KeyEventRouterTests: XCTestCase {
    func testRightCommandFlagsChangedEmitsHeldAndReleasedChanges() {
        var router = KeyEventRouter()

        XCTAssertEqual(router.route(input(kind: .flagsChanged, keyCode: KeyCode.rightCommand, flags: [.maskCommand])), .rightCommandChanged(true))
        XCTAssertTrue(router.isRightCommandHeld)

        XCTAssertEqual(router.route(input(kind: .flagsChanged, keyCode: KeyCode.rightCommand)), .rightCommandChanged(false))
        XCTAssertFalse(router.isRightCommandHeld)
    }

    func testRightCommandLetterRoutesActivateShortcutAndSuppressesKeyUp() {
        var router = KeyEventRouter()
        _ = router.route(input(kind: .flagsChanged, keyCode: KeyCode.rightCommand, flags: [.maskCommand]))

        let decision = router.route(input(kind: .keyDown, keyCode: KeyCode.c, flags: [.maskCommand]))

        XCTAssertEqual(shortcut(from: decision)?.kind, .activate)
        XCTAssertEqual(shortcut(from: decision)?.letter, "c")
        XCTAssertEqual(shortcut(from: decision)?.keyCode, KeyCode.c)
        XCTAssertEqual(router.route(input(kind: .keyUp, keyCode: KeyCode.c, flags: [.maskCommand])), .suppress)
    }

    func testRightCommandRightOptionLetterRoutesAssignShortcut() {
        var router = KeyEventRouter()
        _ = router.route(input(kind: .flagsChanged, keyCode: KeyCode.rightCommand, flags: [.maskCommand]))
        _ = router.route(input(kind: .flagsChanged, keyCode: KeyCode.rightOption, flags: [.maskCommand, .maskAlternate]))

        let decision = router.route(input(kind: .keyDown, keyCode: KeyCode.d, flags: [.maskCommand, .maskAlternate]))

        XCTAssertEqual(shortcut(from: decision)?.kind, .assign)
        XCTAssertEqual(shortcut(from: decision)?.letter, "d")
    }

    func testRightCommandTabAndSpaceRouteSpecialShortcuts() {
        var router = KeyEventRouter()
        _ = router.route(input(kind: .flagsChanged, keyCode: KeyCode.rightCommand, flags: [.maskCommand]))

        XCTAssertEqual(shortcut(from: router.route(input(kind: .keyDown, keyCode: KeyCode.tab, flags: [.maskCommand])))?.kind, .cycleWindow)
        XCTAssertEqual(shortcut(from: router.route(input(kind: .keyDown, keyCode: KeyCode.space, flags: [.maskCommand])))?.kind, .openWindowSearch)
    }

    func testAutorepeatDoesNotRouteShortcut() {
        var router = KeyEventRouter()
        _ = router.route(input(kind: .flagsChanged, keyCode: KeyCode.rightCommand, flags: [.maskCommand]))

        XCTAssertEqual(router.route(input(kind: .keyDown, keyCode: KeyCode.c, flags: [.maskCommand], isAutorepeat: true)), .passThrough)
    }

    func testWindowSearchRoutesNavigationEditingAndText() {
        var router = KeyEventRouter()

        XCTAssertEqual(
            router.route(input(kind: .keyDown, keyCode: KeyCode.arrowDown, isWindowSearchActive: true)),
            .windowSearchAction(.moveDown)
        )
        XCTAssertEqual(
            router.route(input(kind: .keyDown, keyCode: KeyCode.arrowUp, isWindowSearchActive: true)),
            .windowSearchAction(.moveUp)
        )
        XCTAssertEqual(
            router.route(input(kind: .keyDown, keyCode: KeyCode.return, isWindowSearchActive: true)),
            .windowSearchAction(.submit)
        )
        XCTAssertEqual(
            router.route(input(kind: .keyDown, keyCode: KeyCode.escape, isWindowSearchActive: true)),
            .windowSearchAction(.close)
        )
        XCTAssertEqual(
            router.route(input(kind: .keyDown, keyCode: KeyCode.delete, isWindowSearchActive: true)),
            .windowSearchAction(.deleteBackward)
        )
        XCTAssertEqual(
            router.route(input(kind: .keyDown, keyCode: KeyCode.c, isWindowSearchActive: true, printableText: "с")),
            .windowSearchAction(.insertText("с"))
        )
    }

    func testWindowSearchPassesThroughControlAndOptionShortcuts() {
        var router = KeyEventRouter()

        XCTAssertEqual(
            router.route(input(kind: .keyDown, keyCode: KeyCode.space, flags: [.maskControl], isWindowSearchActive: true)),
            .passThrough
        )
        XCTAssertEqual(
            router.route(input(kind: .keyDown, keyCode: KeyCode.space, flags: [.maskAlternate], isWindowSearchActive: true)),
            .passThrough
        )
    }

    func testWindowSearchRightCommandSpaceStillTogglesSearch() {
        var router = KeyEventRouter()
        _ = router.route(input(kind: .flagsChanged, keyCode: KeyCode.rightCommand, flags: [.maskCommand]))

        let decision = router.route(input(kind: .keyDown, keyCode: KeyCode.space, flags: [.maskCommand], isWindowSearchActive: true))

        XCTAssertEqual(shortcut(from: decision)?.kind, .openWindowSearch)
    }

    private func input(
        kind: KeyEventKind,
        keyCode: Int64,
        flags: CGEventFlags = [],
        isAutorepeat: Bool = false,
        isWindowSearchActive: Bool = false,
        printableText: String? = nil
    ) -> KeyEventRoutingInput {
        KeyEventRoutingInput(
            event: KeyEvent(kind: kind, keyCode: keyCode, rawFlags: flags.rawValue, timestamp: Date(timeIntervalSince1970: 0)),
            isAutorepeat: isAutorepeat,
            isWindowSearchActive: isWindowSearchActive,
            keyMappingMode: .physical,
            printableText: printableText
        )
    }

    private func shortcut(from decision: KeyEventRouteDecision) -> KeyShortcut? {
        guard case .shortcut(let shortcut) = decision else {
            return nil
        }

        return shortcut
    }
}
