import XCTest
@testable import Write

final class ValidationCorpusTests: XCTestCase {

    private static let characterLimit = 80
    private static let falseRejectMarginAtNaturalSize = 0.01
    private static let falseAcceptCeilingAtNormal = 0.09

    private func heldOutCharacters() throws -> [SyntheticStrokeCorpus.CorpusCharacter] {
        guard let url = Bundle.main.url(forResource: "kanji_strokes", withExtension: "json")
                ?? Bundle(for: type(of: self)).url(forResource: "kanji_strokes", withExtension: "json") else {
            throw XCTSkip("kanji_strokes.json not found in app or test bundle")
        }
        let store = try KanjiDataStore(data: Data(contentsOf: url))
        let entries = store.allCodePoints.compactMap { codePoint -> (codePoint: String, strokes: [KanjiStroke])? in
            guard let kanji = store.lookup(codePoint: codePoint) else {
                return nil
            }
            return (codePoint, kanji.strokes)
        }
        let selected = SyntheticStrokeCorpus.select(from: entries, strokeCounts: 3...15, limit: Self.characterLimit)
        XCTAssertEqual(selected.count, Self.characterLimit)
        return selected.filter(SyntheticStrokeCorpus.isHeldOut)
    }

    func testReferenceSizedCharactersPassAndMistakesAreCaught() throws {
        let heldOut = try heldOutCharacters()
        XCTAssertGreaterThanOrEqual(heldOut.count, 25)

        let configs = GradingStrictness.allCases.map { strictness -> ValidationConfig in
            var config = ValidationConfig.standard
            config.leniency = strictness.leniency
            return config
        }
        let reports = SyntheticStrokeCorpus.evaluate(heldOut, configs: configs)
        let rows = zip(GradingStrictness.allCases, reports).map {
            (label: "fixed", strictness: $0.0, report: $0.1)
        }
        print(SyntheticStrokeCorpus.describe(title: "Held-out synthetic corpus", characters: heldOut, reports: rows))

        func report(_ strictness: GradingStrictness) -> SyntheticStrokeCorpus.CorpusReport {
            rows.first { $0.strictness == strictness }!.report
        }

        for strictness in GradingStrictness.allCases {
            let natural = report(strictness).falseRejects[1.0] ?? SyntheticStrokeCorpus.CorpusTally()
            XCTAssertGreaterThan(natural.judged, 0)
            XCTAssertLessThanOrEqual(
                Double(natural.hits),
                Double(natural.judged) * Self.falseRejectMarginAtNaturalSize,
                "false rejects at 1.0x, \(strictness.rawValue)"
            )
        }

        let small = report(.normal).falseRejects[0.7] ?? SyntheticStrokeCorpus.CorpusTally()
        XCTAssertGreaterThan(small.hits, 0, "a character drawn at 0.7x must not be followed by the reference")

        let normal = report(.normal)
        XCTAssertGreaterThan(normal.totalFalseAccepts.judged, 0)
        XCTAssertLessThanOrEqual(normal.totalFalseAccepts.rate, Self.falseAcceptCeilingAtNormal)

        let truncatedNormal = normal.falseAccepts[.truncated]?.hits ?? 0
        let truncatedStrict = report(.strict).falseAccepts[.truncated]?.hits ?? 0
        XCTAssertLessThan(truncatedStrict, truncatedNormal, "Strict must reject truncated strokes more often than Normal")

        XCTAssertEqual(report(.strict).disproportionateCorrectStrokes.hits, 0)
    }

    func testCorpusIsDeterministic() {
        let strokes = [
            KanjiStroke(strokeNumber: 1, pathData: "M25,25 L85,25", strokeType: nil),
            KanjiStroke(strokeNumber: 2, pathData: "M55,25 L55,90", strokeType: nil),
            KanjiStroke(strokeNumber: 3, pathData: "M20,90 L90,90", strokeType: nil),
        ]
        let character = SyntheticStrokeCorpus.CorpusCharacter(codePoint: "571f", strokes: strokes)
        let first = SyntheticStrokeCorpus.evaluate([character], configs: [.standard])
        let second = SyntheticStrokeCorpus.evaluate([character], configs: [.standard])
        XCTAssertEqual(first[0].falseRejects, second[0].falseRejects)
        XCTAssertEqual(first[0].falseAccepts, second[0].falseAccepts)
        XCTAssertGreaterThan(first[0].totalFalseRejects.judged, 0)
    }
}
