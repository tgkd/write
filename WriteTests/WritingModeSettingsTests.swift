import XCTest
@testable import Write

@MainActor
final class WritingModeSettingsTests: XCTestCase {
    func testWritingChoicePersistsSeparatelyFromPracticeGuide() throws {
        let name = "WritingModeSettingsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        settings.practiceMode = .copy
        settings.writingMode = .empty
        let loaded = AppSettings(defaults: defaults)
        XCTAssertEqual(loaded.writingMode, .empty)
        XCTAssertEqual(loaded.practiceMode, .copy)
        defaults.set("future", forKey: AppSettings.writingModeKey)
        XCTAssertEqual(AppSettings(defaults: defaults).writingMode, .free)
    }
}
