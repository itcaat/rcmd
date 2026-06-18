import CoreGraphics
import XCTest
@testable import RcmdApp

final class WindowSearchFilterTests: XCTestCase {
    func testEmptyQueryReturnsWindowsInOriginalOrder() {
        let windows = [
            window(appName: "Finder", title: "Downloads", bundleIdentifier: "com.apple.finder"),
            window(appName: "Google Chrome", title: "rcmd README", bundleIdentifier: "com.google.Chrome")
        ]

        XCTAssertEqual(WindowSearchFilter.filteredWindows(windows, query: ""), windows)
        XCTAssertEqual(WindowSearchFilter.filteredWindows(windows, query: "   "), windows)
    }

    func testQueryMatchesAppTitleAndBundleIdentifier() {
        let finder = window(appName: "Finder", title: "Downloads", bundleIdentifier: "com.apple.finder")
        let chrome = window(appName: "Google Chrome", title: "rcmd README", bundleIdentifier: "com.google.Chrome")
        let preview = window(appName: "Preview", title: "Screenshot", bundleIdentifier: "com.apple.Preview")
        let windows = [finder, chrome, preview]

        XCTAssertEqual(WindowSearchFilter.filteredWindows(windows, query: "chrome"), [chrome])
        XCTAssertEqual(WindowSearchFilter.filteredWindows(windows, query: "readme"), [chrome])
        XCTAssertEqual(WindowSearchFilter.filteredWindows(windows, query: "apple preview"), [preview])
    }

    func testQueryRequiresAllTokens() {
        let matchingWindow = window(appName: "Google Chrome", title: "rcmd README", bundleIdentifier: "com.google.Chrome")
        let appOnlyWindow = window(appName: "Google Chrome", title: "Calendar", bundleIdentifier: "com.google.Chrome")
        let titleOnlyWindow = window(appName: "Preview", title: "rcmd README", bundleIdentifier: "com.apple.Preview")

        XCTAssertEqual(
            WindowSearchFilter.filteredWindows([matchingWindow, appOnlyWindow, titleOnlyWindow], query: "chrome readme"),
            [matchingWindow]
        )
    }

    func testDisplayedWindowsAppliesLimitAfterFiltering() {
        let windows = (0..<5).map { index in
            window(appName: "Finder", title: "Folder \(index)", bundleIdentifier: "com.apple.finder", processIdentifier: pid_t(index))
        }

        XCTAssertEqual(WindowSearchFilter.displayedWindows(windows, query: "folder", limit: 2), Array(windows.prefix(2)))
    }

    private func window(
        appName: String,
        title: String,
        bundleIdentifier: String,
        processIdentifier: pid_t = 42
    ) -> WindowInfo {
        WindowInfo(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            appURL: nil,
            processIdentifier: processIdentifier,
            title: title,
            isMinimized: false,
            frame: CGRect(x: 10, y: 20, width: 800, height: 600),
            isFocused: false
        )
    }
}
