import CoreGraphics

struct StrokeAnchor: Equatable, Sendable {
    let referenceIndex: Int
    let userCentroid: CGPoint
    var userExtent: CGFloat = 0
}
