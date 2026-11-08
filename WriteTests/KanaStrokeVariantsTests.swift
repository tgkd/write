import XCTest
@testable import Write

@MainActor
final class KanaStrokeVariantsTests: XCTestCase {

    private let canvas = CGSize(width: 439, height: 439)
    private let uStrokes = [
        KanjiStroke(strokeNumber: 1, pathData: "M42,15.5c5.62,2.12,9.62,3,12.88,3c8.27,0,8,1.12-0.38,5.5", strokeType: nil),
        KanjiStroke(strokeNumber: 2, pathData: "M33,42.38c2.12,1.12,4.12,2.88,8.5,1.38c4.38-1.5,12.75-7.12,18.5-7c5.75,0.12,10.25,5,10.25,18c0,15.49-8.25,30.24-24.37,41.24", strokeType: nil)
    ]

    private func config(_ strictness: GradingStrictness) -> ValidationConfig {
        var config = ValidationConfig.standard
        config.leniency = strictness.leniency
        return config
    }

    private var samples: [[CGPoint]] {
        StrokeValidator.sampleReferenceStrokes(uStrokes, canvasSize: canvas, sampleCount: ValidationConfig.standard.sampleCount)
    }

    private var alternates: [Int: [[CGPoint]]] {
        [0: KanaStrokeVariants.curlVariants(of: samples[0])]
    }

    private func accepted(
        _ points: [CGPoint],
        strictness: GradingStrictness = .strict,
        alternates: [Int: [[CGPoint]]]? = nil
    ) -> Bool {
        let result = StrokeValidator.identifyStroke(
            userPoints: points,
            referenceSamples: samples,
            unmatchedIndices: [0],
            canvasSize: canvas,
            expectedStrokeIndex: 0,
            anchors: [],
            alternates: alternates ?? self.alternates,
            config: config(strictness)
        )
        return result.accepted && result.correctOrder
    }

    private var plainDash: [CGPoint] {
        alternates[0]?.first ?? []
    }

    private func dash(tail length: CGFloat) -> [CGPoint] {
        let reference = samples[0]
        let body = plainDash
        guard let bodyEnd = body.last, let end = reference.last else {
            return []
        }
        let stepCount = 12
        let tail = (1...stepCount).map { step -> CGPoint in
            let t = length * CGFloat(step) / CGFloat(stepCount)
            return CGPoint(x: bodyEnd.x + (end.x - bodyEnd.x) * t, y: bodyEnd.y + (end.y - bodyEnd.y) * t)
        }
        return body + tail
    }

    private func makeKanji(text: String, strokes: [KanjiStroke]) -> KanjiData {
        KanjiData(codePoint: "3046", element: text, strokes: strokes, components: [])
    }

    func testTableNamesTheCurledDashes() {
        XCTAssertEqual(KanaStrokeVariants.curledStrokeIndices(text: "う", strokeCount: 2), [0])
        XCTAssertEqual(KanaStrokeVariants.curledStrokeIndices(text: "ふ", strokeCount: 4), [0, 3])
        XCTAssertEqual(KanaStrokeVariants.curledStrokeIndices(text: "ぶ", strokeCount: 6), [0, 3])
        XCTAssertEqual(KanaStrokeVariants.curledStrokeIndices(text: "や", strokeCount: 3), [1])
    }

    func testSmallYaAddsItsDashAfterTheBaseStrokes() {
        XCTAssertEqual(KanaStrokeVariants.curledStrokeIndices(text: "きゃ", strokeCount: 7), [5])
        XCTAssertEqual(KanaStrokeVariants.curledStrokeIndices(text: "にゃ", strokeCount: 6), [1, 4])
        XCTAssertEqual(KanaStrokeVariants.curledStrokeIndices(text: "にゅ", strokeCount: 5), [1])
    }

    func testOtherCharactersHaveNoVariant() {
        XCTAssertTrue(KanaStrokeVariants.curledStrokeIndices(text: "口", strokeCount: 3).isEmpty)
        XCTAssertTrue(KanaStrokeVariants.curledStrokeIndices(text: "ウ", strokeCount: 3).isEmpty)
        XCTAssertTrue(KanaStrokeVariants.curledStrokeIndices(text: "あ", strokeCount: 3).isEmpty)
    }

    func testEveryListedStrokeHasCurlVariantsShorterAndLongerThanItsReference() throws {
        guard let url = Bundle.main.url(forResource: "kanji_strokes", withExtension: "json")
                ?? Bundle(for: type(of: self)).url(forResource: "kanji_strokes", withExtension: "json") else {
            throw XCTSkip("kanji_strokes.json not found in app or test bundle")
        }
        let store = try KanjiDataStore(data: Data(contentsOf: url))
        var listed = 0
        for codePoint in store.allCodePoints {
            guard let kanji = store.lookup(codePoint: codePoint), kanji.script != .kanji else {
                continue
            }
            let indices = KanaStrokeVariants.curledStrokeIndices(text: kanji.text, strokeCount: kanji.strokes.count)
            guard !indices.isEmpty else {
                continue
            }
            let references = StrokeValidator.sampleReferenceStrokes(kanji.strokes, canvasSize: canvas, sampleCount: 50)
            for index in indices {
                listed += 1
                let lengths = KanaStrokeVariants.curlVariants(of: references[index]).map(arcLength)
                let fullLength = arcLength(references[index])
                let label = "\(kanji.text) stroke \(index + 1)"
                let body = try XCTUnwrap(lengths.first, label)
                let longest = try XCTUnwrap(lengths.last, label)
                XCTAssertLessThan(body, fullLength * 0.9, label)
                XCTAssertGreaterThan(body, fullLength * 0.55, label)
                XCTAssertGreaterThan(longest, fullLength * 1.02, label)
            }
        }
        XCTAssertGreaterThanOrEqual(listed, 17)
    }

    func testPlainDashPassesOnlyWithTheVariant() {
        XCTAssertFalse(accepted(plainDash, alternates: [:]))
        XCTAssertTrue(accepted(plainDash))
        XCTAssertTrue(accepted(plainDash, strictness: .normal))
    }

    func testCurledFormStillPasses() {
        XCTAssertTrue(accepted(samples[0]))
    }

    func testReversedDashIsRejected() {
        XCTAssertFalse(accepted(plainDash.reversed()))
        XCTAssertFalse(accepted(plainDash.reversed(), strictness: .normal))
    }

    func testPerpendicularDashIsRejected() {
        let center = ProcrustesNormalizer.centroid(of: plainDash)
        let turned = plainDash.map { CGPoint(x: center.x - ($0.y - center.y), y: center.y + ($0.x - center.x)) }
        XCTAssertFalse(accepted(turned))
        XCTAssertFalse(accepted(turned, strictness: .normal))
    }

    func testMisplacedDashIsRejected() {
        let moved = plainDash.map { CGPoint(x: $0.x, y: $0.y + 60) }
        XCTAssertFalse(accepted(moved))
        XCTAssertFalse(accepted(moved, strictness: .normal))
    }

    func testStrictChecksTheSizeOfThePlainDash() {
        let center = ProcrustesNormalizer.centroid(of: plainDash)
        let small = plainDash.map { CGPoint(x: center.x + ($0.x - center.x) * 0.6, y: center.y + ($0.y - center.y) * 0.6) }
        XCTAssertFalse(accepted(small))
    }

    func testCurlLengthIsNotGraded() {
        for length in [CGFloat(0.5), 1.2, 1.5] {
            XCTAssertTrue(accepted(dash(tail: length)), "tail \(length)")
        }
    }

    func testFarTooLongTailIsRejected() {
        XCTAssertFalse(accepted(dash(tail: 4)))
        XCTAssertFalse(accepted(dash(tail: 4), strictness: .normal))
    }

    func testVariantAppliesInEveryMode() {
        let kanji = makeKanji(text: "う", strokes: uStrokes)
        for mode in [PracticeMode.trace, .strokeByStroke, .copy] {
            XCTAssertEqual(Set(PracticeState(kanjiData: kanji, mode: mode).alternateSamples(canvasSize: canvas).keys), [0])
        }
        XCTAssertEqual(Set(PracticeState(kanjiData: kanji, isRecall: true).alternateSamples(canvasSize: canvas).keys), [0])
    }

    private func arcLength(_ points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }
}
