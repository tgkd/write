import Foundation
import UIKit

struct StrokeCaptureContext: Equatable, Sendable {
    let codePoint: String
    let mode: String
}

struct CapturedSample: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let t: Double
    var force: Double?
    var altitude: Double?

    static func samples(from canvasSamples: [BrushStroke.Sample]) -> [CapturedSample] {
        guard let start = canvasSamples.first?.timestamp else {
            return []
        }
        return canvasSamples.map { sample in
            CapturedSample(
                x: Double(sample.point.x),
                y: Double(sample.point.y),
                t: sample.timestamp - start,
                force: sample.force.map { Double($0) },
                altitude: sample.altitude.map { Double($0) }
            )
        }
    }
}

struct CapturedStroke: Codable, Equatable, Sendable {
    let id: UUID
    let codePoint: String
    let mode: String
    let touchType: String
    let canvasWidth: Double
    let canvasHeight: Double
    let samples: [CapturedSample]

    init(
        id: UUID,
        codePoint: String,
        mode: String,
        touchType: String,
        canvasWidth: Double,
        canvasHeight: Double,
        samples: [CapturedSample]
    ) {
        self.id = id
        self.codePoint = codePoint
        self.mode = mode
        self.touchType = touchType
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.samples = samples
    }

    init(capture: CanvasStrokeCapture, context: StrokeCaptureContext) {
        self.init(
            id: capture.id,
            codePoint: context.codePoint,
            mode: context.mode,
            touchType: Self.touchTypeName(capture.touchType),
            canvasWidth: Double(capture.canvasSize.width),
            canvasHeight: Double(capture.canvasSize.height),
            samples: CapturedSample.samples(from: capture.samples)
        )
    }

    static func touchTypeName(_ type: UITouch.TouchType) -> String {
        switch type {
        case .pencil:
            return "pencil"
        case .direct:
            return "finger"
        default:
            return "other"
        }
    }
}

struct CanvasStrokeCapture {
    let id: UUID
    let touchType: UITouch.TouchType
    let canvasSize: CGSize
    let samples: [BrushStroke.Sample]
}
