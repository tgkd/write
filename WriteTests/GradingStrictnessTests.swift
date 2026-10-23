import XCTest
@testable import Write

@MainActor
final class GradingStrictnessTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "GradingStrictnessTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func migrated(fromWidth width: Double) -> GradingStrictness {
        defaults.set(width, forKey: "maskPathWidth")
        return AppSettings(defaults: defaults).gradingStrictness
    }

    func testNarrowGuideMigratesToStrict() {
        XCTAssertEqual(migrated(fromWidth: 3), .strict)
    }

    func testDefaultGuideMigratesToNormal() {
        XCTAssertEqual(migrated(fromWidth: 5), .normal)
    }

    func testWidestGuideMigratesToNormal() {
        XCTAssertEqual(migrated(fromWidth: 14), .normal)
    }

    func testMissingWidthDefaultsToStrict() {
        XCTAssertEqual(AppSettings(defaults: defaults).gradingStrictness, .strict)
    }

    func testMigrationIsStoredSoLaterWidthChangesDoNotRemigrate() {
        XCTAssertEqual(migrated(fromWidth: 3), .strict)
        XCTAssertEqual(defaults.string(forKey: "gradingStrictness"), "strict")

        let settings = AppSettings(defaults: defaults)
        settings.maskPathWidth = 14

        XCTAssertEqual(AppSettings(defaults: defaults).gradingStrictness, .strict)
    }

    func testAbsentWidthStoresStrict() {
        _ = AppSettings(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: "gradingStrictness"), "strict")

        let settings = AppSettings(defaults: defaults)
        settings.maskPathWidth = 14

        XCTAssertEqual(AppSettings(defaults: defaults).gradingStrictness, .strict)
    }

    func testStrictnessPersists() {
        let settings = AppSettings(defaults: defaults)
        settings.gradingStrictness = .strict
        XCTAssertEqual(AppSettings(defaults: defaults).gradingStrictness, .strict)

        settings.gradingStrictness = .normal
        XCTAssertEqual(AppSettings(defaults: defaults).gradingStrictness, .normal)
    }

    func testStoredStrictnessWinsOverWidth() {
        defaults.set("normal", forKey: "gradingStrictness")
        XCTAssertEqual(migrated(fromWidth: 3), .normal)
    }

    func testRemovedLenientBecomesNormal() {
        defaults.set("lenient", forKey: "gradingStrictness")
        XCTAssertEqual(migrated(fromWidth: 3), .normal)
        XCTAssertEqual(defaults.string(forKey: "gradingStrictness"), "normal")
    }

    func testValidationConfigFollowsStrictness() {
        let settings = AppSettings(defaults: defaults)
        for strictness in GradingStrictness.allCases {
            settings.gradingStrictness = strictness
            XCTAssertEqual(settings.validationConfig.leniency, strictness.leniency)
        }
    }

    func testGuideWidthNeverChangesValidationConfig() {
        let settings = AppSettings(defaults: defaults)
        for strictness in GradingStrictness.allCases {
            settings.gradingStrictness = strictness
            let expected = settings.validationConfig
            for width in stride(from: AppSettings.maskPathWidthRange.lowerBound, through: AppSettings.maskPathWidthRange.upperBound, by: 0.5) {
                settings.maskPathWidth = width
                let config = settings.validationConfig
                XCTAssertEqual(config.leniency, expected.leniency)
                XCTAssertEqual(config.shapeThreshold, expected.shapeThreshold)
                XCTAssertEqual(config.centroidTolerance, expected.centroidTolerance)
                XCTAssertEqual(config.positionTolerance, expected.positionTolerance)
                XCTAssertEqual(config.guidelessPositionTolerance, expected.guidelessPositionTolerance)
                XCTAssertEqual(config.sampleCount, expected.sampleCount)
            }
        }
    }
}
