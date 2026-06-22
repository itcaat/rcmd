import XCTest
@testable import RcmdApp

final class L10nTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        super.tearDown()
    }

    func testUsesAppleLanguagesArgumentWhenSupported() {
        UserDefaults.standard.set(["ru"], forKey: "AppleLanguages")

        XCTAssertEqual(L10n.tr("quickStart.title"), "Быстрый старт")
    }

    func testFallsBackToEnglishWhenLanguageIsUnsupported() {
        UserDefaults.standard.set(["ja"], forKey: "AppleLanguages")

        XCTAssertEqual(L10n.tr("quickStart.title"), "Quick Start")
    }

    func testMatchesRegionSpecificPreferredLanguageToBaseLocalization() {
        UserDefaults.standard.set(["de-DE"], forKey: "AppleLanguages")

        XCTAssertEqual(L10n.tr("quickStart.title"), "Schnellstart")
    }
}
