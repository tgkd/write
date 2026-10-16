import Foundation

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
}

struct CapturedStroke: Codable, Equatable, Sendable {
    let id: UUID
    let codePoint: String
    let mode: String
    let touchType: String
    let canvasWidth: Double
    let canvasHeight: Double
    let samples: [CapturedSample]
}
