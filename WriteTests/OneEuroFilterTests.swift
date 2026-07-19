import XCTest
import CoreGraphics
@testable import Write

final class OneEuroFilterTests: XCTestCase {

    /// Deterministic pseudo-random generator so the test is reproducible.
    private struct LCG {
        var state: UInt64
        /// Returns a value in [-1, 1).
        mutating func nextSigned() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = CGFloat(state >> 11) / CGFloat(UInt64(1) << 53)
            return unit * 2 - 1
        }
    }

    func testSeedReturnsFirstPointUnchanged() {
        var filter = OneEuroFilter()
        let point = CGPoint(x: 12.5, y: 42.25)
        XCTAssertEqual(filter.filter(point: point, timestamp: 0), point)
    }

    func testConvergesToConstantInput() {
        var filter = OneEuroFilter(minCutoff: 1.0, beta: 0.0)
        let target = CGPoint(x: 200, y: 300)
        _ = filter.filter(point: CGPoint(x: 0, y: 0), timestamp: 0)

        var result = CGPoint.zero
        for i in 1...100 {
            result = filter.filter(point: target, timestamp: TimeInterval(i) / 60.0)
        }
        XCTAssertEqual(result.x, target.x, accuracy: 0.1)
        XCTAssertEqual(result.y, target.y, accuracy: 0.1)
    }

    /// The behavioral contract of the smoothing setting: SmoothingStrength.high
    /// must remove more noise than SmoothingStrength.low. Noise is applied
    /// perpendicular to a horizontal stroke so filter lag (which acts along the
    /// stroke) does not pollute the measurement.
    func testHighSettingSmoothsMoreThanLowSetting() {
        func residual(minCutoff: CGFloat, beta: CGFloat) -> CGFloat {
            var filter = OneEuroFilter(minCutoff: minCutoff, beta: beta)
            var noise = LCG(state: 42)
            var sum: CGFloat = 0
            for i in 0..<120 {
                let point = CGPoint(x: CGFloat(i) * 2, y: 100 + noise.nextSigned() * 2)
                let filtered = filter.filter(point: point, timestamp: TimeInterval(i) / 120.0)
                if i >= 10 {
                    let dy = filtered.y - 100
                    sum += dy * dy
                }
            }
            return sum
        }

        let high = SmoothingStrength.high.filterParams
        let low = SmoothingStrength.low.filterParams
        let highResidual = residual(minCutoff: high.minCutoff, beta: high.beta)
        let lowResidual = residual(minCutoff: low.minCutoff, beta: low.beta)

        XCTAssertLessThan(highResidual, lowResidual,
            "The High smoothing setting must suppress noise more than Low")
    }
}
