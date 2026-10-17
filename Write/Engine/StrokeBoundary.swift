import CoreGraphics

enum StrokeBoundary {
    static func excursion(of points: [CGPoint], canvasSize: CGSize) -> CGFloat? {
        let width = canvasSize.width
        let height = canvasSize.height
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            return nil
        }
        var farthest: CGFloat = 0
        for point in points {
            guard point.x.isFinite, point.y.isFinite else {
                return nil
            }
            let dx = max(-point.x, point.x - width, 0)
            let dy = max(-point.y, point.y - height, 0)
            farthest = max(farthest, hypot(dx, dy))
        }
        return farthest / min(width, height)
    }
}
