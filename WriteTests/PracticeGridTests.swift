import SwiftUI
import XCTest
@testable import Write

@MainActor
final class PracticeGridTests: XCTestCase {

    private func makeKanji() -> KanjiData {
        KanjiData(
            codePoint: "4e00",
            element: nil,
            strokes: [KanjiStroke(strokeNumber: 1, pathData: "M10,50 L90,50", strokeType: nil)],
            components: []
        )
    }

    func testGridLinesSpanASquareCanvasAtTheirPosition() {
        let middle = StrokeRenderer.kanjiVGSize / 2
        let bounds = PracticeGridLines(positions: [middle])
            .path(in: CGRect(x: 0, y: 0, width: 300, height: 300))
            .boundingRect

        XCTAssertEqual(bounds.minX, 0, accuracy: 0.001)
        XCTAssertEqual(bounds.maxX, 300, accuracy: 0.001)
        XCTAssertEqual(bounds.minY, 0, accuracy: 0.001)
        XCTAssertEqual(bounds.maxY, 300, accuracy: 0.001)
    }

    func testGridFollowsTheSameTransformAsTheReference() {
        let size = CGSize(width: 400, height: 300)
        let bounds = PracticeGridLines(positions: [0])
            .path(in: CGRect(origin: .zero, size: size))
            .boundingRect
        let origin = CGPoint.zero.applying(StrokeRenderer.scaleTransform(to: size))

        XCTAssertEqual(bounds.minX, origin.x, accuracy: 0.001)
        XCTAssertEqual(bounds.minY, origin.y, accuracy: 0.001)
        XCTAssertEqual(bounds.width, 300, accuracy: 0.001)
    }

    func testModelShowsInCopyAndRecallOnly() {
        let kanji = makeKanji()
        XCTAssertFalse(PracticeState(kanjiData: kanji, mode: .trace).showsPracticeModel)
        XCTAssertFalse(PracticeState(kanjiData: kanji, mode: .strokeByStroke).showsPracticeModel)
        XCTAssertTrue(PracticeState(kanjiData: kanji, mode: .copy).showsPracticeModel)
        XCTAssertTrue(PracticeState(kanjiData: kanji, isRecall: true).showsPracticeModel)
    }

    func testRecallKeepsTheModelHiddenUntilTheCharacterHint() {
        let state = PracticeState(kanjiData: makeKanji(), isRecall: true)
        XCTAssertTrue(state.hidesCharacter)

        state.showNextHint()

        XCTAssertFalse(state.hidesCharacter)
        XCTAssertTrue(state.hidesGuide)
    }

    func testGridSettingDefaultsOnAndPersists() throws {
        let suite = "PracticeGridTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
        }

        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.showPracticeGrid)

        settings.showPracticeGrid = false
        XCTAssertFalse(AppSettings(defaults: defaults).showPracticeGrid)
    }
}
