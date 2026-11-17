import CoreGraphics

struct BrushRaster {
    let width: Int
    let height: Int
    let origin: CGPoint
    let scale: CGFloat

    init(bounds: CGRect, scale: CGFloat = 2) {
        width = max(1, Int((bounds.width * scale).rounded(.up)))
        height = max(1, Int((bounds.height * scale).rounded(.up)))
        origin = bounds.origin
        self.scale = scale
    }

    init(covering paths: [CGPath], margin: CGFloat = 4, scale: CGFloat = 2) {
        let box = paths.map(\.boundingBoxOfPath).reduce(CGRect.null) { $0.union($1) }
        self.init(bounds: box.insetBy(dx: -margin, dy: -margin), scale: scale)
    }

    var pixelArea: CGFloat { 1 / (scale * scale) }

    func mask(_ path: CGPath) -> [UInt8] {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return [] }
        context.setShouldAntialias(false)
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -origin.x, y: -origin.y)
        context.setFillColor(gray: 1, alpha: 1)
        context.addPath(path)
        context.fillPath()
        guard let data = context.data else { return [] }
        let rowBytes = context.bytesPerRow
        let pixels = data.bindMemory(to: UInt8.self, capacity: rowBytes * height)
        var result = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                result[y * width + x] = pixels[y * rowBytes + x] > 127 ? 1 : 0
            }
        }
        return result
    }

    func point(_ index: Int) -> CGPoint {
        let column = index % width
        let row = index / width
        return CGPoint(
            x: origin.x + (CGFloat(column) + 0.5) / scale,
            y: origin.y + (CGFloat(height - 1 - row) + 0.5) / scale
        )
    }

    func differingArea(_ a: CGPath, _ b: CGPath, where include: (CGPoint) -> Bool = { _ in true }) -> CGFloat {
        let maskA = mask(a)
        let maskB = mask(b)
        var count = 0
        for index in maskA.indices where maskA[index] != maskB[index] && include(point(index)) {
            count += 1
        }
        return CGFloat(count) * pixelArea
    }

    func coarseDifferences(_ a: CGPath, _ b: CGPath, where include: (CGPoint) -> Bool) -> [CGPoint] {
        let maskA = mask(a)
        let maskB = mask(b)
        var result: [CGPoint] = []
        for index in maskA.indices where maskA[index] != maskB[index] && include(point(index)) {
            let other = maskA[index] == 1 ? maskB : maskA
            if !hasNeighbor(in: other, at: index) {
                result.append(point(index))
            }
        }
        return result
    }

    private func hasNeighbor(in mask: [UInt8], at index: Int) -> Bool {
        let column = index % width
        let row = index / width
        for dy in -1...1 {
            for dx in -1...1 {
                let x = column + dx
                let y = row + dy
                if x >= 0, x < width, y >= 0, y < height, mask[y * width + x] == 1 {
                    return true
                }
            }
        }
        return false
    }
}
