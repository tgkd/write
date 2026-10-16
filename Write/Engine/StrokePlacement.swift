import CoreGraphics

struct StrokePlacement: Equatable, Sendable {
    var scale: CGFloat
    var offset: CGVector

    static let identity = StrokePlacement(scale: 1, offset: .zero)

    func apply(to point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scale + offset.dx, y: point.y * scale + offset.dy)
    }
}
