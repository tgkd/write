import XCTest
@testable import Write

@MainActor
final class PencilGestureSettingsTests: XCTestCase {
    func testDoubleTapOnAndSqueezeOffByDefault() throws {
        let name = "PencilGestureSettingsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.pencilDoubleTapEnabled)
        XCTAssertFalse(settings.pencilSqueezeEnabled)
        XCTAssertTrue(AppSettings.isPencilDoubleTapEnabled(in: defaults))
        XCTAssertFalse(AppSettings.isPencilSqueezeEnabled(in: defaults))
    }

    func testChoicesPersist() throws {
        let name = "PencilGestureSettingsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        settings.pencilDoubleTapEnabled = false
        settings.pencilSqueezeEnabled = true
        let loaded = AppSettings(defaults: defaults)
        XCTAssertFalse(loaded.pencilDoubleTapEnabled)
        XCTAssertTrue(loaded.pencilSqueezeEnabled)
        XCTAssertFalse(AppSettings.isPencilDoubleTapEnabled(in: defaults))
        XCTAssertTrue(AppSettings.isPencilSqueezeEnabled(in: defaults))
    }
}
