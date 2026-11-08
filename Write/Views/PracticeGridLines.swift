import SwiftUI

struct PracticeGridLines: Shape {
    let positions: [CGFloat]

    func path(in rect: CGRect) -> Path {
        let transform = StrokeRenderer.scaleTransform(to: rect.size)
        let extent = StrokeRenderer.kanjiVGSize
        var path = Path()
        for position in positions {
            path.move(to: CGPoint(x: position, y: 0).applying(transform))
            path.addLine(to: CGPoint(x: position, y: extent).applying(transform))
            path.move(to: CGPoint(x: 0, y: position).applying(transform))
            path.addLine(to: CGPoint(x: extent, y: position).applying(transform))
        }
        return path
    }
}
