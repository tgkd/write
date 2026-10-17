import XCTest
@testable import Write

@MainActor
final class WordPracticeSettingTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "WordPracticeSettingTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private var storedValue: Bool? {
        defaults.object(forKey: "showWordPractice") as? Bool
    }

    func testAbsentKeyHidesWordPractice() {
        XCTAssertNil(defaults.object(forKey: "showWordPractice"))
        XCTAssertFalse(AppSettings(defaults: defaults).showWordPractice)
    }

    func testTurningOnWritesTrue() {
        let settings = AppSettings(defaults: defaults)
        settings.showWordPractice = true
        XCTAssertEqual(storedValue, true)
    }

    func testNewSettingsReadTheStoredValue() {
        AppSettings(defaults: defaults).showWordPractice = true
        XCTAssertTrue(AppSettings(defaults: defaults).showWordPractice)
    }

    func testTurningOffPersistsFalse() {
        let settings = AppSettings(defaults: defaults)
        settings.showWordPractice = true
        settings.showWordPractice = false
        XCTAssertEqual(storedValue, false)
        XCTAssertFalse(AppSettings(defaults: defaults).showWordPractice)
    }
}
