import UIKit
import XCTest
@testable import Write

@MainActor
final class PencilActionResponderTests: XCTestCase {
    func testTapRunsActionForActivePreferences() {
        var runCount = 0
        let responder = PencilActionResponder { runCount += 1 }
        let preferences: [UIPencilPreferredAction] = [.switchEraser, .switchPrevious, .showColorPalette]
        for preference in preferences {
            responder.handleTap(preference: preference)
        }
        XCTAssertEqual(runCount, preferences.count)
    }

    func testTapIgnoredWhenPreferenceIsIgnore() {
        var runCount = 0
        let responder = PencilActionResponder { runCount += 1 }
        responder.handleTap(preference: .ignore)
        XCTAssertEqual(runCount, 0)
    }

    func testSqueezeRunsActionOnceAcrossFullGesture() throws {
        guard #available(iOS 17.5, *) else {
            throw XCTSkip("Squeeze needs iOS 17.5")
        }
        var runCount = 0
        let responder = PencilActionResponder { runCount += 1 }
        for phase in [UIPencilInteraction.Phase.began, .changed, .changed, .ended] {
            responder.handleSqueeze(phase: phase, preference: .switchEraser)
        }
        XCTAssertEqual(runCount, 1)
    }

    func testSqueezeIgnoresNonEndedPhases() throws {
        guard #available(iOS 17.5, *) else {
            throw XCTSkip("Squeeze needs iOS 17.5")
        }
        var runCount = 0
        let responder = PencilActionResponder { runCount += 1 }
        for phase in [UIPencilInteraction.Phase.began, .changed, .cancelled] {
            responder.handleSqueeze(phase: phase, preference: .switchEraser)
        }
        XCTAssertEqual(runCount, 0)
    }

    func testSqueezeIgnoredWhenPreferenceIsIgnore() throws {
        guard #available(iOS 17.5, *) else {
            throw XCTSkip("Squeeze needs iOS 17.5")
        }
        var runCount = 0
        let responder = PencilActionResponder { runCount += 1 }
        responder.handleSqueeze(phase: .ended, preference: .ignore)
        XCTAssertEqual(runCount, 0)
    }

    func testTapIgnoredWhenDisabled() {
        var runCount = 0
        let responder = PencilActionResponder { runCount += 1 }
        responder.handleTap(preference: .switchEraser, isEnabled: false)
        XCTAssertEqual(runCount, 0)
    }

    func testSqueezeIgnoredWhenDisabled() throws {
        guard #available(iOS 17.5, *) else {
            throw XCTSkip("Squeeze needs iOS 17.5")
        }
        var runCount = 0
        let responder = PencilActionResponder { runCount += 1 }
        responder.handleSqueeze(phase: .ended, preference: .switchEraser, isEnabled: false)
        XCTAssertEqual(runCount, 0)
    }
}
