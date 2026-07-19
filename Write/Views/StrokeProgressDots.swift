import SwiftUI

/// One dot per reference stroke: colored when matched, highlighted when next.
struct StrokeProgressDots: View {
    @ObservedObject var practiceState: PracticeState
    let palette: ColorPalette

    var body: some View {
        let total = practiceState.totalStrokes
        let dotSize: CGFloat = total <= 12 ? 10 : (total <= 20 ? 8 : 6)

        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(fillColor(for: i))
                    .frame(width: dotSize, height: dotSize)
                    .overlay(
                        Circle()
                            .stroke(borderColor(for: i), lineWidth: 1)
                    )
            }
        }
    }

    private func fillColor(for index: Int) -> Color {
        if practiceState.matchedStrokeIndices.contains(index) {
            return Color(uiColor: palette.strokeOrderColor(
                index: index, total: practiceState.totalStrokes
            ))
        }
        if index == practiceState.currentStrokeIndex && !practiceState.isComplete {
            return Color(.systemGray4)
        }
        return Color(.systemGray6)
    }

    private func borderColor(for index: Int) -> Color {
        if practiceState.matchedStrokeIndices.contains(index) {
            return .clear
        }
        if index == practiceState.currentStrokeIndex && !practiceState.isComplete {
            return Color(.systemGray3)
        }
        return Color(.systemGray5)
    }
}
