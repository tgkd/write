import SwiftUI

struct WordFlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(maxWidth: bounds.width, subviews: subviews)
        for (index, frame) in arrangement.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var lines: [[Int]] = [[]]
        var lineWidths: [CGFloat] = [0]
        let sizes = subviews.map { subview -> CGSize in
            let ideal = subview.sizeThatFits(.unspecified)
            guard ideal.width > maxWidth else {
                return ideal
            }
            return subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
        }

        for (index, size) in sizes.enumerated() {
            let current = lineWidths[lineWidths.count - 1]
            let needed = current == 0 ? size.width : current + spacing + size.width
            if needed > maxWidth, current > 0 {
                lines.append([index])
                lineWidths.append(size.width)
            } else {
                lines[lines.count - 1].append(index)
                lineWidths[lineWidths.count - 1] = needed
            }
        }

        var frames = Array(repeating: CGRect.zero, count: sizes.count)
        var y: CGFloat = 0
        var width: CGFloat = 0
        for (lineIndex, line) in lines.enumerated() where !line.isEmpty {
            let height = line.map { sizes[$0].height }.max() ?? 0
            var x: CGFloat = 0
            for index in line {
                let size = sizes[index]
                frames[index] = CGRect(x: x, y: y + (height - size.height) / 2, width: size.width, height: size.height)
                x += size.width + spacing
            }
            width = max(width, lineWidths[lineIndex])
            y += height + lineSpacing
        }
        let totalHeight = max(0, y - lineSpacing)
        return (frames, CGSize(width: width, height: totalHeight))
    }
}
