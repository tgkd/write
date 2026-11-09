import XCTest
@testable import Write

@MainActor
final class WritingCellSmokeTests: XCTestCase {
    func testReferenceAndFixedNoiseAcrossCanvasSizes() throws {
        let store = KanjiDataStore()
        for side: CGFloat in [200, 300, 600] {
            let size = CGSize(width: side, height: side)
            for strictness in GradingStrictness.allCases {
                for recall in [false, true] {
                    for noise: CGFloat in [0, 2] {
                        var accepted = 0
                        var total = 0
                        var failures: [String] = []
                        var config = ValidationConfig.standard
                        config.leniency = strictness.leniency
                        for character: Character in ["一", "水", "待", "う", "が", "ぱ", "ぴ", "鬱"] {
                            let data = try XCTUnwrap(store.lookup(character: character))
                            let state = PracticeState(kanjiData: data, mode: .trace, isRecall: recall, config: config)
                            let references = state.referenceSamples(canvasSize: size)
                            var anchors: [StrokeAnchor] = []
                            for index in references.indices {
                                let points = references[index].enumerated().map { i, point in
                                    CGPoint(x: point.x + noise * sin(CGFloat(i) * 1.3), y: point.y + noise * cos(CGFloat(i) * 1.7))
                                }
                                let trimmed = StrokeHookTrimmer.trim(points, parameters: .init(canvasSize: size))
                                let result = StrokeValidator.identifyStroke(
                                    userPoints: trimmed, referenceSamples: references,
                                    unmatchedIndices: Set(index..<references.count), canvasSize: size,
                                    expectedStrokeIndex: index, anchors: recall ? anchors : nil,
                                    alternates: state.alternateSamples(canvasSize: size), config: config
                                )
                                XCTAssertTrue(result.score.isFinite)
                                XCTAssertTrue(result.frechetDistance.isFinite)
                                total += 1
                                if result.accepted && result.correctOrder {
                                    accepted += 1
                                    if let anchor = result.anchor { anchors.append(anchor) }
                                } else {
                                    failures.append("\(character)#\(index + 1)")
                                }
                            }
                        }
                        print("\(Int(side))pt synthetic smoke \(strictness.rawValue) \(recall ? "empty" : "trace") noise=\(noise)pt: \(accepted)/\(total) accepted")
                        if side == 200, !failures.isEmpty {
                            print("200pt failures \(strictness.rawValue) \(recall ? "empty" : "trace") noise=\(noise)pt: \(failures.joined(separator: ", "))")
                        }
                        XCTAssertGreaterThan(total, 0)
                    }
                }
            }
        }
    }
}
