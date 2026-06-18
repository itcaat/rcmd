import XCTest
@testable import RcmdApp

@MainActor
final class AssignmentStoreTests: XCTestCase {
    func testDefaultConfigStartsWithSafeValues() {
        let store = AssignmentStore(configURL: temporaryConfigURL())

        XCTAssertEqual(store.assignmentsByLetter, [:])
        XCTAssertEqual(store.keyMappingMode, .activeLayout)
        XCTAssertFalse(store.minimizeActiveWindowOnRepeatedShortcut)
    }

    func testSavingAndLoadingConfigPersistsSettingsAndAssignments() {
        let configURL = temporaryConfigURL()
        let store = AssignmentStore(configURL: configURL)

        store.setKeyMappingMode(.physical)
        store.setMinimizeActiveWindowOnRepeatedShortcut(true)
        store.set(bundleIdentifier: "com.google.Chrome", for: "C")
        store.set(bundleIdentifier: "com.apple.finder", for: "f")

        let loadedStore = AssignmentStore(configURL: configURL)

        XCTAssertEqual(loadedStore.keyMappingMode, .physical)
        XCTAssertTrue(loadedStore.minimizeActiveWindowOnRepeatedShortcut)
        XCTAssertEqual(loadedStore.bundleIdentifier(for: "c"), "com.google.Chrome")
        XCTAssertEqual(loadedStore.bundleIdentifier(for: "F"), "com.apple.finder")
    }

    func testLoadingOlderConfigWithoutMinimizeSettingKeepsDefaultDisabled() throws {
        let configURL = temporaryConfigURL()
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        # rcmd configuration
        keyMappingMode: physical
        assignments:
          z: dev.zed.Zed
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let store = AssignmentStore(configURL: configURL)

        XCTAssertEqual(store.keyMappingMode, .physical)
        XCTAssertFalse(store.minimizeActiveWindowOnRepeatedShortcut)
        XCTAssertEqual(store.bundleIdentifier(for: "z"), "dev.zed.Zed")
    }

    private func temporaryConfigURL(file: StaticString = #filePath, line: UInt = #line) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rcmd-tests-\(UUID().uuidString)", isDirectory: true)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        return directory.appendingPathComponent("config.yaml")
    }
}
