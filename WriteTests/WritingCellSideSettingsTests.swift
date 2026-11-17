import XCTest
@testable import Write

@MainActor
final class WritingCellSideSettingsTests: XCTestCase {
    func testCellSideDefaultsPersistsAndClampsStoredValues() throws {
        let name = "WritingCellSideSettingsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.writingCellSide, AppSettings.defaultWritingCellSide)

        settings.writingCellSide = 260
        XCTAssertEqual(AppSettings(defaults: defaults).writingCellSide, 260)

        defaults.set(5000.0, forKey: "writingCellSide")
        XCTAssertEqual(AppSettings(defaults: defaults).writingCellSide, AppSettings.writingCellSideRange.upperBound)

        defaults.set(10.0, forKey: "writingCellSide")
        XCTAssertEqual(AppSettings(defaults: defaults).writingCellSide, AppSettings.writingCellSideRange.lowerBound)
    }
}
